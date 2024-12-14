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
ldapsearch -x -H "LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    error_exit "Senha do administrador LDAP incorreta."
fi

# Solicitar o nome do grupo
read -p "Digite o nome do grupo: " GROUPNAME
if [[ -z "$GROUPNAME" ]]; then
    error_exit "O nome do grupo não pode estar vazio."
fi

# Verificar se o grupo já existe
if ldapsearch -x -H "LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" -b "$GROUP_BASE_DN" "cn=$GROUPNAME" | grep -q "dn:"; then
    error_exit "O grupo '$GROUPNAME' já existe no LDAP."
fi

# Buscar o próximo gidNumber disponível
LAST_GID=$(ldapsearch -x -H "LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" -b "$GROUP_BASE_DN" "(gidNumber=*)" gidNumber | awk '/gidNumber:/ {print $2}' | sort -n | tail -n 1)
if [[ -z "$LAST_GID" ]]; then
    NEXT_GID=5000 # Início padrão se nenhum gidNumber existir
else
    NEXT_GID=$((LAST_GID + 1))
fi

# Solicitar o gidNumber ou usar o próximo disponível
read -p "Digite o gidNumber (ou pressione Enter para usar o próximo disponível: $NEXT_GID): " GIDNUMBER
if [[ -z "$GIDNUMBER" ]]; then
    GIDNUMBER=$NEXT_GID
fi

# Verificar se o gidNumber já está em uso
if ldapsearch -x -H "LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" -b "$GROUP_BASE_DN" "gidNumber=$GIDNUMBER" | grep -q "gidNumber:"; then
    error_exit "O gidNumber '$GIDNUMBER' já está em uso por outro grupo no LDAP."
fi

# Criar o LDIF para o grupo
GROUP_DN="cn=$GROUPNAME,$GROUP_BASE_DN"
GROUP_LDIF=$(cat <<EOF
dn: $GROUP_DN
objectClass: top
objectClass: posixGroup
cn: $GROUPNAME
gidNumber: $GIDNUMBER
EOF
)

# Exibir o LDIF gerado
echo "LDIF do grupo gerado:"
echo "$GROUP_LDIF"

# Adicionar o grupo no LDAP
echo "$GROUP_LDIF" | ldapadd -x -H "LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS"
if [[ $? -ne 0 ]]; then
    error_exit "Erro ao adicionar o grupo '$GROUPNAME' ao LDAP."
fi

echo "Grupo '$GROUPNAME' criado com sucesso! gidNumber: $GIDNUMBER."
