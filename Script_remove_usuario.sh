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
ldapsearch -x -H "LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" -b "$BASE_DN" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    error_exit "Senha do administrador LDAP incorreta."
fi

# Solicitar o nome de usuário
read -p "Digite o nome do usuário a ser removido: " USERNAME
if [[ -z "$USERNAME" ]]; then
    error_exit "O nome do usuário não pode estar vazio."
fi

# Verificar se o usuário existe
USER_DN="uid=$USERNAME,$BASE_DN"
if ! ldapsearch -x -H "LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" -b "$BASE_DN" "uid=$USERNAME" | grep -q "dn: "; then
    error_exit "Erro: O usuário '$USERNAME' não foi encontrado no LDAP."
fi

# Confirmar remoção do usuário
read -p "Tem certeza de que deseja remover o usuário '$USERNAME' (s/n)? " CONFIRM
if [[ ! "$CONFIRM" =~ [sS]$ ]]; then
    echo "Operação cancelada."
    exit 0
fi

# Remover o usuário do LDAP
ldapdelete -x -H "LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" "$USER_DN"
if [[ $? -ne 0 ]]; then
    error_exit "Erro ao remover o usuário '$USERNAME' do LDAP."
fi

echo "Usuário '$USERNAME' removido com sucesso do LDAP."
