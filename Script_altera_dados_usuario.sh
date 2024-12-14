#!/bin/bash

# Configurações do servidor LDAP (credenciais definidas diretamente no script)
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
read -p "Digite o nome de usuário a ser alterado: " USERNAME
if [[ -z "$USERNAME" ]]; then
    error_exit "O nome de usuário não pode estar vazio."
fi

# Verificar se o usuário existe
USER_DN="uid=$USERNAME,$BASE_DN"
USER_EXIST=$(ldapsearch -x -H "$LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS" -b "$BASE_DN" "uid=$USERNAME" | grep -q "dn:")

if [[ $? -ne 0 ]]; then
    error_exit "Erro: O usuário '$USERNAME' não foi encontrado no LDAP."
fi

# Solicitar dados para atualizar
read -p "Digite o novo nome completo (exemplo: Luiz Henrique de Campos Monteiro) [deixe em branco para manter o atual]: " CN
read -p "Digite o novo sobrenome (exemplo: Monteiro) [deixe em branco para manter o atual]: " SN
read -p "Digite o novo nome de exibição (exemplo: Henrique Monteiro) [deixe em branco para manter o atual]: " DISPLAYNAME
read -p "Digite o novo e-mail (exemplo: henrique.monteiro@empresa.com.br) [deixe em branco para manter o atual]: " MAIL

# Solicitar nova senha caso necessário
read -p "Deseja alterar a senha? (s/n): " ALTERAR_SENHA
if [[ "$ALTERAR_SENHA" == "S" ]]; then
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
fi

# Criar o LDIF com as alterações
LDIF="dn: $USER_DN
changetype: modify
"

if [[ -n "$CN" ]]; then
    LDIF+="replace: cn
cn: $CN
"
fi
if [[ -n "$SN" ]]; then
    LDIF+="replace: sn
sn: $SN
"
fi
if [[ -n "$DISPLAYNAME" ]]; then
    LDIF+="replace: displayName
displayName: $DISPLAYNAME
"
fi
if [[ -n "$MAIL" ]]; then
    LDIF+="replace: mail
mail: $MAIL
"
fi
if [[ "$ALTERAR_SENHA" == "S" ]]; then
    LDIF+="replace: userPassword
userPassword: $PASSWORD_HASH
"
fi

# Exibir o LDIF gerado
echo "LDIF gerado:"
echo "$LDIF"

# Aplicar as alterações no LDAP
echo "$LDIF" | ldapmodify -x -H "$LDAP_SERVER" -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASS"
if [[ $? -ne 0 ]]; then
    error_exit "Erro ao modificar o usuário no LDAP."
fi

echo "Dados do usuário '$USERNAME' atualizados com sucesso!"
