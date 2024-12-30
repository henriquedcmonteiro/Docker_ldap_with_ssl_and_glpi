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
ldapsearch -x -H "$LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" -b "$BASE_DN" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    error_exit "Senha do administrador LDAP incorreta."
fi

# Verifica argumentos
if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <grupo> <membro>"
    echo "Este script adiciona um membro ao grupo."
    exit 1
fi

GROUP_NAME="$1"
MEMBER="$2"
GROUP_DN="cn=$GROUP_NAME,ou=groups,dc=empresa,dc=local"  # Ajuste o DN conforme necessário

# Função para verificar se o usuário existe no LDAP
does_user_exist() {
    ldapsearch -x -H "$LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" \
        -b "ou=users,dc=empresa,dc=local" "(uid=$MEMBER)" | grep -q "dn:"
    return $?
}

# Função para verificar se o membro está no grupo
is_member_in_group() {
    ldapsearch -x -H "$LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" \
        -b "$GROUP_DN" "(memberUid=$MEMBER)" | grep -q "memberUid: $MEMBER"
    return $?
}

# Verifica se o usuário existe
if ! does_user_exist; then
    echo "Erro: O usuário '$MEMBER' não existe no LDAP."
    exit 1
fi

# Verifica se o membro já está no grupo
if is_member_in_group; then
    echo "Erro: O membro '$MEMBER' já está no grupo '$GROUP_NAME'."
    exit 1
fi

# Adiciona membro ao grupo
cat <<EOF | ldapmodify -x -H "$LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS"
dn: $GROUP_DN
changetype: modify
add: memberUid
memberUid: $MEMBER
EOF

if [ $? -eq 0 ]; then
    echo "Membro '$MEMBER' adicionado com sucesso ao grupo '$GROUP_NAME'."
else
    echo "Erro ao adicionar o membro '$MEMBER' ao grupo '$GROUP_NAME'. Verifique as configurações e tente novamente."
fi

