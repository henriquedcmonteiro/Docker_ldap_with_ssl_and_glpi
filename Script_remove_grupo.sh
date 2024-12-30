#!/bin/bash

# Configurações do servidor LDAP
LDAP_SERVER="ldaps://ldap-server"
LDAP_ADMIN_DN="cn=admin,dc=empresa,dc=local"
GROUP_BASE_DN="ou=groups,dc=empresa,dc=local"

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

# Solicitar o nome do grupo
read -p "Digite o nome do grupo para remover: " GROUPNAME
if [[ -z "$GROUPNAME" ]]; then
    error_exit "O nome do grupo não pode estar vazio."
fi

# Verificar se o grupo existe
GROUP_DN="cn=$GROUPNAME,$GROUP_BASE_DN"
if ! ldapsearch -x -H "$LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" -b "$GROUP_BASE_DN" "cn=$GROUPNAME" | grep -q "dn:"; then
    error_exit "Erro: O grupo '$GROUPNAME' não existe no LDAP."
fi

# Confirmar remoção
read -p "Tem certeza que deseja remover o grupo '$GROUPNAME'? (s/n): " CONFIRM
if [[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]]; then
    echo "Operação cancelada. O grupo '$GROUPNAME' não foi removido."
    exit 0
fi

# Remover o grupo do LDAP
ldapdelete -x -H "$LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" "$GROUP_DN"
if [[ $? -ne 0 ]]; then
    error_exit "Erro ao remover o grupo '$GROUPNAME' do LDAP."
fi

echo "Grupo '$GROUPNAME' removido com sucesso!"

