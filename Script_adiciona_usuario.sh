Script adicionar usuario
#!/bin/bash
Configurações do servidor LDAP
LDAP_SERVER="ldaps://ldap-server"
LDAP_ADMIN_DN="cn=admin,dc=empresa,dc=local"
BASE_DN="ou=users,dc=empresa,dc=local"
Função para exibir mensagens de erro
function error_exit() {
echo "Erro: $1" >&2
exit 1
}
Solicitar a senha do administrador LDAP
read -s -p "Digite a senha do administrador LDAP: " LDAP_ADMIN_PASS
echo
Validar a senha fornecida
ldapsearch -x -H " LDAP_ADMIN_DN" -w "
BASE_DN" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
error_exit "Senha do administrador LDAP incorreta."
fi
Solicitar o nome de usuário
read -p "Digite o nome de usuário: " USERNAME
if [[ -z "$USERNAME" ]]; then
error_exit "O nome de usuário não pode estar vazio."
fi
Verificar se o uid já existe
LDAP ERV ER" −S D" LDAP DM IN ASS" −A P b"
if ldapsearch -x -H " LDAP_ADMIN_DN" -w "
BASE_DN" "uid=
USERNAME' já existe no LDAP."
fi
Buscar o próximo uidNumber disponível
LAST_UID= LDAP_SERVER" -D "
LDAP_ADMIN_PASS" -b "$BASE_DN" "(uidNumber=*)" uidNumber | awk '/uidNumber:/ {print
KaTeX parse error: Expected 'EOF', got '}' at position 2: 2}̲' | sort -n | t…
LAST_UID" ]]; then
NEXT_UID=1000 # Início padrão se nenhum uidNumber existir
else
NEXT_UID=$((LAST_UID + 1))
fi
Solicitar dados adicionais
read -p "Digite o nome completo (exemplo: Luiz Henrique de Campos Monteiro): " CN
read -p "Digite o sobrenome (exemplo: Monteiro): " SN
read -p "Digite o nome de exibição (exemplo: Henrique Monteiro): " DISPLAYNAME
read -p "Digite o e-mail (exemplo: henrique.monteiro@empresa.com.br): " MAIL
Solicitar e confirmar a senha
while true; do
read -s -p "Digite a senha: " PASSWORD
echo
read -s -p "Confirme a senha: " PASSWORD_CONFIRM
echo
if [[ "$PASSWORD" == "$PASSWORD_CONFIRM" ]]; then
break
else
echo "As senhas não coincidem. Tente novamente."
fi
done
Gerar o hash da senha
LDAP ERV ER" −S D" LDAP DM IN ASS" −A P
b" U SERN AME"∣grep − q"dn : "; thenerror xit"Erro :e
Onomedeusu rioaˊ ′
(ldapsearch − x − H" LDAP DM IN N " −A D w"
PASSWORD_HASH= PASSWORD")
if [[ $? -ne 0 ]]; then
error_exit "Erro ao gerar o hash da senha."
fi
Montar o DN do usuário
USER_DN="uid= BASE_DN"
Criar o LDIF para o usuário
LDIF=$(cat <<EOF
dn: $USER_DN
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: $CN
sn: $SN
givenName: $CN
uid: $USERNAME
uidNumber: $NEXT_UID
gidNumber: USERNAME
userPassword: $PASSWORD_HASH
loginShell: /bin/bash
displayName: $DISPLAYNAME
mail: $MAIL
EOF
)
Exibir o LDIF gerado
echo "LDIF gerado:"
echo "$LDIF"
Adicionar o usuário no LDAP
echo " LDAP_SERVER" -D "
LDAP_ADMIN_PASS"
if [[ $? -ne 0 ]]; then
error_exit "Erro ao adicionar o usuário ao LDAP."
fi
echo "Usuário $USERNAME criado com sucesso! uidNumber: $NEXT_UID"
(slappasswd − s"
U SERN AME,
NEXT IDhomeDirectory :U /home/
LDIF "∣ldapadd − x − H" LDAP DM IN N " −A D w"
