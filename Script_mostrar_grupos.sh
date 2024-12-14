#!/bin/bash

# Configurações LDAP
LDAP_SERVER="ldaps://ldap-server"
LDAP_ADMIN_DN="cn=admin,dc=empresa,dc=local"
BASE_DN="ou=groups,dc=empresa,dc=local"

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

# Busca todos os grupos e seus GIDs
ldapsearch -x -H "$LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" -b "$BASE_DN" "(objectClass=posixGroup)" gidNumber cn | grep -E "cn:|gidNumber:" | paste - - | awk '{print $4 "\t" $2}'

