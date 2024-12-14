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
read -p "Digite o nome de usuário a ser desativado: " USERNAME
if [[ -z "$USERNAME" ]]; then
    error_exit "O nome de usuário não pode estar vazio."
fi

# Verificar se o usuário existe
USER_DN=$(ldapsearch -x -H "LDAP_SERVER" -D "LDAP_ADMIN_DN" -w "LDAP_ADMIN_PASS" -b "BASE_DN" "(uid=$USERNAME)" dn | awk '/^dn: / {print $2}')
if [[ -z "$USER_DN" ]]; then
    error_exit "Erro: O usuário '$USERNAME' não foi encontrado no LDAP."
fi

# Criar LDIF para desativar o usuário
LDIF=$(cat <<EOF
dn: $USER_DN
changetype: modify
replace: loginShell
loginShell: /usr/sbin/nologin
replace: userPassword
userPassword: *
EOF
)

# Exibir o LDIF gerado
echo "LDIF gerado:"
echo "$LDIF"

# Aplicar as alterações no LDAP
echo "$LDIF" | ldapmodify -x -H "LDAP_SERVER" -D "LDAP_ADMIN_DN" -w "LDAP_ADMIN_PASS"
if [[ $? -ne 0 ]]; then
    error_exit "Erro ao desativar o usuário no LDAP."
fi

echo "Usuário $USERNAME desativado com sucesso!"

# Opcional: Remover permissões ou vínculos em serviços relacionados
echo "Removendo permissões do usuário em serviços vinculados..."
# (ldapsearch -x -H "LDAP_SERVER" -D "LDAP_ADMIN_DN" -w "LDAP_ADMIN_PASS" -b "BASE_DN" "(uid=$USERNAME)" dn)

# Exemplo: chamar scripts ou APIs para remoção
./remove_user_from_service.sh "$USERNAME"

echo "Processo concluído."
