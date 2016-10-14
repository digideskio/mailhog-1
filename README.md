# MailHog Dockerfile

## Usage
Start MailHog and the sample app:
```sh
docker-compose up -d
```

Retrieve the Docker hostname:
```sh
DOCKER_HOSTNAME="$(echo "${DOCKER_HOST:-localhost}" | sed 's#.*/##;s#:.*##')"
```

Open the MailHog web interface and the sample app and send some email:
```sh
open http://"$DOCKER_HOSTNAME":8025
open http://"$DOCKER_HOSTNAME":8080
```

Or send email via the command-line script:
```sh
echo 'Email text' | ./srv/mail.sh -h "$DOCKER_HOSTNAME" -p 1025
```

Stop and remove the Docker container set:
```sh
docker-compose down
```

## License
Released under the [MIT license](http://opensource.org/licenses/MIT).

## Author
[Sebastian Tschan](https://blueimp.net/)
