#!/bin/bash

# Configurações do servidor LDAP
LDAP_SERVER="ldaps://ldap-server"
LDAP_ADMIN_DN="cn=admin,dc=empresa,dc=local"
BASE_DN="ou=users,dc=empresa,dc=local"

# Função para exibir mensagens de erro
function error_exit() {
    echo "Erro: $1" >&2
    exit 1
}

# Solicitar a senha do administrador LDAP
read -s -p "Digite a senha do administrador LDAP: " LDAP_ADMIN_PASS
echo

# Validar a senha fornecida
ldapsearch -x -H "LDAP_SERVER" -D "LDAP_ADMIN_DN" -w "BASE_DN" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    error_exit "Senha do administrador LDAP incorreta."
fi

# Solicitar o nome de usuário
read -p "Digite o nome de usuário a ser reativado: " USERNAME
if [[ -z "$USERNAME" ]]; then
    error_exit "O nome de usuário não pode estar vazio."
fi

# Verificar se o usuário existe no LDAP
USER_DN= $(ldapsearch -x -H "LDAP_SERVER" -D "LDAP_ADMIN_DN" -w "LDAP_ADMIN_PASS" -b "BASE_DN" "(uid=$USERNAME)" dn | awk '/dn: / {print $2}')
if [[ -z "$USER_DN" ]]; then
    error_exit "Usuário '$USERNAME' não encontrado no LDAP."
fi

# Verificar o loginShell atual do usuário
CURRENT_SHELL=$(ldapsearch -x -H "LDAP_SERVER" -D "LDAP_ADMIN_DN" -w "LDAP_ADMIN_PASS" -b "$USER_DN" loginShell | awk '/loginShell: / {print $2}')
if [[ "$CURRENT_SHELL" == "/bin/bash" ]]; then
    echo "Usuário '$USERNAME' já está ativo."
    exit 0
fi

# Solicitar uma nova senha para o usuário
while true; do
    read -s -p "Digite uma nova senha para o usuário: " PASSWORD
    echo
    read -s -p "Confirme a nova senha: " PASSWORD_CONFIRM
    echo
    if [[ "$PASSWORD" == "$PASSWORD_CONFIRM" ]]; then
        break
    else
        echo "As senhas não coincidem. Tente novamente."
    fi
done

# Gerar o hash da nova senha
PASSWORD_HASH= $(slappasswd -s "$PASSWORD")
if [[ $? -ne 0 ]]; then
    error_exit "Erro ao gerar o hash da senha."
fi

# Criar um arquivo LDIF para reativar o usuário
LDIF=$(cat <<EOF
dn: $USER_DN
changetype: modify
replace: loginShell
loginShell: /bin/bash
replace: userPassword
userPassword: $PASSWORD_HASH
EOF
)

# Exibir o LDIF gerado
echo "LDIF gerado para reativação do usuário:"
echo "$LDIF"

# Aplicar as alterações no LDAP
echo "$LDIF" | ldapmodify -x -H "LDAP_SERVER" -D "LDAP_ADMIN_DN" -w "LDAP_ADMIN_PASS"
if [[ $? -ne 0 ]]; then
    error_exit "Erro ao reativar o usuário '$USERNAME' no LDAP."
fi

echo "Usuário '$USERNAME' reativado com sucesso!"
