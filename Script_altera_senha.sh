#!/bin/bash

# Configurações do servidor LDAP
LDAP_SERVER="ldaps://ldap-server"
LDAP_ADMIN_DN="cn=admin,dc=empresa,dc=local"
USER_BASE_DN="ou=users,dc=empresa,dc=local"

# Função para exibir mensagens de erro
function error_exit() {
    echo "Erro: $1" >&2
    exit 1
}

# Solicitar a senha do administrador LDAP
read -s -p "Digite a senha do administrador LDAP: " LDAP_ADMIN_PASS
echo

# Validar a senha fornecida
ldapsearch -x -H "LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" -b "$USER_BASE_DN" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    error_exit "Senha do administrador LDAP incorreta."
fi

# Solicitar o nome do usuário
read -p "Digite o nome do usuário para alterar a senha: " USERNAME
if [[ -z "$USERNAME" ]]; then
    error_exit "O nome do usuário não pode estar vazio."
fi

# Verificar se o usuário existe
USER_DN="uid=$USERNAME,$USER_BASE_DN"
if ! ldapsearch -x -H "LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" -b "$USER_BASE_DN" "uid=$USERNAME" | grep -q "dn: "; then
    error_exit "Erro: O usuário '$USERNAME' não foi encontrado no LDAP."
fi

# Solicitar e confirmar a nova senha
while true; do
    read -s -p "Digite a nova senha: " PASSWORD
    echo
    read -s -p "Confirme a nova senha: " PASSWORD_CONFIRM
    echo
    if [[ "$PASSWORD" == "$PASSWORD_CONFIRM" ]]; then
        break
    else
        echo "As senhas não coincidem. Tente novamente."
    fi
done

# Gerar o hash da senha
PASSWORD_HASH=$(slappasswd -s "$PASSWORD")
if [[ $? -ne 0 ]]; then
    error_exit "Erro ao gerar o hash da senha."
fi

# Montar o LDIF para a alteração da senha
LDIF=$(cat <<EOF
dn: $USER_DN
changetype: modify
replace: userPassword
userPassword: $PASSWORD_HASH
EOF
)

# Exibir o LDIF gerado
echo "LDIF gerado para alterar a senha do usuário '$USERNAME':"
echo "$LDIF"

# Alterar a senha no LDAP
echo "$LDIF" | ldapmodify -x -H "$LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS"
if [[ $? -ne 0 ]]; then
    error_exit "Erro ao alterar a senha do usuário '$USERNAME'."
fi

echo "A senha do usuário '$USERNAME' foi alterada com sucesso!"
