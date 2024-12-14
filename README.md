<h1>Vamos começar pelo LDAP</h1>

A principio vamos criar um docker-compose.yml em uma pasta chamada ldap na home do docker.

`vim docker-compose.yml`

Vamos inserir o código abaixo dentro do arquivo.

```
version: '3'

services:
  ldap:
    image: osixia/openldap:1.5.0
    container_name: openldap
    hostname: ldap-server
    environment:
      - LDAP_TLS=true
      - LDAP_ORGANISATION=Minha_empresa
      - LDAP_DOMAIN=empresa.local
      - LDAP_ENABLE_TLS=true
      - LDAP_ADMIN_PASSWORD=admin
      - LDAP_TLS_CERT_FILE=/container/service/slapd/assets/certs/ldap.crt
      - LDAP_TLS_KEY_FILE=/container/service/slapd/assets/certs/ldap.key
      - LDAP_TLS_CA_FILE=/container/service/slapd/assets/certs/ca.crt
      - LDAP_TLS_ENFORCE=true
      - LDAP_TLS_VERIFY_CLIENT=never
      - LDAP_LDAPS_PORT_NUMBER=636
      - CONTAINER_LOG_LEVEL=4
    ports:
      - "636:636"
    volumes:
      - ldap-certs:/container/service/slapd/assets/certs/
      - ./scripts:/usr/local/bin/
      - ldap_data:/var/lib/ldap
      - ldap_config:/etc/ldap
    networks:
      - glpi-ldap

volumes:
  ldap-certs:
    external: true
  ldap_data:
    external: true
  ldap_config:
    external: true

networks:
  glpi-ldap:
    external: true

```

Antes criaremos os volumes permanentes referenciados no script e também a network que vai conectar o ldap com o glpi

`docker volume create ldap-certs`

`docker volume create ldap_data`

`docker volume create ldap_config`

`docker network create glpi-ldap`

Note também que existe uma pasta chamada scripts a onde vão estar todos os scripts em shell de
manutenção de usuario, grupo e senha, voltado para os dados que vão ser armazenados no banco do
ldap.

Eles já estaram inseridos no /usr/local/bin podendo ser evocados pelos seus respectitivos nomes.

Os scripts são auto explicativos e vão estar separados para consultas.

Agora vamos executar o docker-compose.

`docker-compose up -d`

Vamos entrar dentro do container com o comando abaixo.

`docker exec -it openldap bash`

Dentro do container vamos criar um arquivo de estrutura para usuarios e grupos. Precisamos criar a estrutura de OU, users e groups.

`vim estrutura_ou.ldif`

```
dn: ou=users,dc=empresa,dc=local
objectClass: organizationalUnit
ou: users

dn: ou=groups,dc=empresa,dc=local
objectClass: organizationalUnit
ou: groups
```

Utilize o comando abaixo para adicionar a estrutura básica principal

`ldapadd -x -H ldaps://localhost -D "cn=admin,dc=empresa,dc=local" -w admin -f estrutura_ou.ldif`

Antes de adicionar o schema de criptografia, checamos se ele já não esta ativo, neste exemplo não.

`ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config "(olcModuleLoad=*)"`

A saída que nos interessa é algo assim:

```
# module{0}, config
dn: cn=module{0},cn=config
objectClass: olcModuleList
cn: module{0}
olcModulePath: /usr/lib/ldap
olcModuleLoad: {0}back_mdb
olcModuleLoad: {1}memberof
olcModuleLoad: {2}refint
```

Note que não há um Modulo de criptografia ativo, vamos ativa-lo seguindo os passos abaixo.

Vamos adicionar um schema para comportar senhas criptografadas em SSHA.

`vim add-pw-sha2.ldif`

```
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: {3}pw-sha2
```

`ldapmodify -Y EXTERNAL -H ldapi:/// -f add-pw-sha2.ldif`

Agora o ldap reconhece chaves SSHAs, agora vamos alterar nossa senha padrão para a senha
utilizada internamente em hash. Para isso rode o comando abaixo para gerar uma chave de
criptografia.

```
python3 -c "import hashlib, os, base64; s = os.urandom(4); print('{SSHA}' +
base64.b64encode(hashlib.sha1(b'senha_nova_adm' + s).digest() + s).decode())"
```

Neste exemplo vai gerar o hash abaixo:

`{SSHA}XuY1Gs3045UDQp1mjKOLFjMk1uRe+B0S`

Nós vamos ter dois modulos que vamos utilizar, o ** {0}** é para configurações do ldap e o ** {1}** é o banco de dado mdb onde estão salvos todas as configurações de usuarios e grupos.

A principio vamos alterar o principal que é referente as configurações, que esta relacionado no docker-compose.yml, nós instalamos com a senha admin, e agora vamos modificar para uma senha segura que determinarmos, neste exemplo vamos usar o hash acima e o comando acima do python.

`vim update-config-password.ldif`

Dentro do arquivo vai estar o conteúdo abaixo:

```
dn: olcDatabase={0}config,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: {SSHA}FF6MI92IRaQUnG1icMveVaQfHUGCIx8s
```

Depois executamos o comando abaixo para modificar a senha antiga pela nova criptografada.

`ldapmodify -Y EXTERNAL -H ldapi:/// -f update-config-password.ldif`

Agora vamos também trocar a senha do banco mdb.

Geramos um novo hash.

```
python3 -c "import hashlib, os, base64; s = os.urandom(4); print('{SSHA}' +
base64.b64encode(hashlib.sha1(b'senha_nova_banco' + s).digest() + s).decode())"
```

`{SSHA}vRkFiWuhA1FnwX9rWoZ8pQkv3wIHB9e0`

Criamos o arquivo e inserimos o novo hash nele para o banco.

`vim change-admin-password.ldif`

Dentro do arquivo o conteudo vai estar sendo este.

```
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: {SSHA}vRkFiWuhA1FnwX9rWoZ8pQkv3wIHB9e0
```

Modificamos a senha do banco e passamos a senha de configuração geral que passamos acima referente ao {0}.

ldapmodify -x -D "cn=admin,cn=config" -W -H ldaps://localhost -f change-admin-password.ldif

Podemos checar se esta funcionando com o comando:

`ldapsearch -x -H ldaps://localhost -D "cn=admin,dc=empresa,dc=local" -W -b "dc=empresa,dc=local" "(objectClass=*)"`

<h2>Utilizando os scripts</h2>

