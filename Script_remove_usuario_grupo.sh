#!/bin/bash

# Configurações LDAP
LDAP_SERVER="ldaps://ldap-server"
LDAP_ADMIN_DN="cn=admin,dc=empresa,dc=local"

# Função para exibir mensagens de erro
function error_exit() {
    echo "Erro: $1" >&2
    exit 1
}

# Solicitar a senha do administrador LDAP
read -s -p "Digite a senha do administrador LDAP: " LDAP_ADMIN_PASS
echo

# Validar a senha fornecida
ldapsearch -x -H "$LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    error_exit "Senha do administrador LDAP incorreta."
fi

# Verifica argumentos
if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <nome_do_grupo> <membro>"
    echo "Este script remove um membro do grupo."
    exit 1
fi

GROUP_NAME="$1"
MEMBER="$2,ou=users,dc=djsystem,dc=local"  # Ajuste o DN conforme necessário

# Função para verificar se o usuário existe no LDAP
does_user_exist() {
    ldapsearch -x -H "$LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" "(uid=$MEMBER)" | grep -q "dn:"
    return $?
}

# Função para verificar se o membro está no grupo
is_member_in_group() {
    GROUP_DN="cn=$GROUP_NAME,ou=groups,dc=djsystem,dc=local"
    ldapsearch -x -H "$LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" -b "$GROUP_DN" "(memberUid=$MEMBER)" | grep -q "memberUid: $MEMBER"
    return $?
}

# Verifica se o usuário existe
if ! does_user_exist; then
    echo "Erro: O usuário '$MEMBER' não existe no LDAP."
    exit 1
fi

# Verifica se o membro está no grupo
if ! is_member_in_group; then
    echo "Erro: O membro '$MEMBER' não está no grupo '$GROUP_NAME'."
    exit 1
fi

# Remove membro do grupo
cat <<EOF | ldapmodify -x -H "$LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS"
dn: $GROUP_DN
changetype: modify
delete: memberUid
memberUid: $MEMBER
EOF

# Verifica se a remoção foi bem-sucedida
if [[ $? -eq 0 ]]; then
    echo "Membro '$MEMBER' removido com sucesso do grupo '$GROUP_NAME'."
else
    echo "Erro ao remover membro '$MEMBER' do grupo '$GROUP_NAME'."
    echo "Verifique as configurações e tente novamente."
fi