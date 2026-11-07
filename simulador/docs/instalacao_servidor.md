# Instalação do servidor de mundo compartilhado

| Item | Exigência |
|---|---|
| PHP | 8.1 ou superior, com `pdo_mysql` (ou `pdo_sqlite`), `json` e `mbstring` |
| Banco | MySQL/MariaDB; SQLite para testes ou poucos usuários |
| Servidor web | Apache ou Nginx, com HTTPS em produção |
| Pasta exposta | Somente `servidor_mundo/public/` |

## Passos

1. Copie `simulador/servidor_mundo/` para o servidor.
2. Copie `config.exemplo.php` para `config.php` e ajuste `dsn`, `usuario` e `senha`.
3. **MySQL:** crie o banco e as tabelas com `mysql -u root -p mundo_drone < sql/schema_mysql.sql`. **SQLite:** as tabelas são criadas sozinhas na primeira chamada. A pasta `dados/` precisa ser gravável pelo PHP.
4. Aponte o servidor web para `public/`. O endereço que o simulador usa é `https://seu.servidor/api.php`.
5. Teste com `curl https://seu.servidor/api.php`. A resposta esperada é `{"ok":true,"versao":1,"raio_m":2000,"intervalo_ms":500}`.

### Apache

O `public/.htaccess` repassa o cabeçalho `Authorization` ao PHP. Sem ele, todas as chamadas com token respondem 401. Habilite `AllowOverride` na pasta, ou copie a linha `SetEnvIf` para a configuração do site.

### Nginx + PHP-FPM

```nginx
server {
    listen 443 ssl;
    server_name mundo.exemplo.com.br;
    root /srv/servidor_mundo/public;
    location = /api.php {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root/api.php;
        fastcgi_param HTTP_AUTHORIZATION $http_authorization;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }
    location / { return 404; }
}
```

### Teste local rápido

```
cd simulador/servidor_mundo/public
php -S 0.0.0.0:8099
```

No simulador, use `http://127.0.0.1:8099/api.php`. Em outra máquina da rede, use `http://<ip>:8099/api.php`.

## Manutenção

- A limpeza é automática: em cerca de 1 a cada 20 chamadas, o servidor apaga os drones parados há mais de 30 s, os eventos com mais de 60 s e os contadores antigos. Nenhum histórico de voo é guardado.
- Atrás de um proxy reverso confiável, ligue `confiar_proxy` para usar o IP de `X-Forwarded-For` nos limites.
- Os limites (raio, validade, taxas) ficam em `config.php`. O raio é imposto pelo servidor, e o cliente não pode pedir outro.
