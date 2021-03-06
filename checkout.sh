#!/bin/sh

BASENAME=$(basename "$0")

print_usage() {
  cat <<EOF
  Usage: $BASENAME COMMAND [arg...]
       $BASENAME [ --help ]

  A self-sufficient runtime for checkout application.

  Commands:
      help                Get detailed help and usage
      start               Start services
      stop                Stop services
      test                Make a POST request using checkout.json file
      database            List checkout database tables (visualize result)

  Run '$BASENAME COMMAND --help' for more information on a command.
EOF
  exit 1
}

start() {
  docker-compose up -d
  while ! docker-compose exec \
    kafka cub kafka-ready -b kafka:9092 1 1 >/dev/null 2>&1
  do
    echo "Kafka nao esta pronto"
    sleep 1
  done
  ./docker/kafka/init-topics.sh
}

stop() {
  docker-compose down
}

test_checkout() {
  curl -X POST \
    -H "Content-Type: application/json" \
    -d "@checkout-test.json" \
    http://localhost:8085/api/v1/checkout/
}

checkout_db() {
  echo 'Database Checkout'
  local tables='checkout_entity shipping_entity checkout_item_entity'
  for i in $tables
  do
    docker-compose exec database-checkout \
      /bin/bash -c "psql -Ucheckout_db_user checkout -c 'select * from $i;'"
  done
}

payment_db() {
  echo 'Database Payment'
  local tables='payment_entity'
  for i in $tables
  do
    docker-compose exec database-payment \
      /bin/bash -c "psql -Upayment_db_user payment -c 'select * from $i;'"
  done
}

mailer_db() {
  echo 'Database Mailer'
  local tables='mail_entity'
  for i in $tables
  do
    docker-compose exec database-mailer \
      /bin/bash -c "psql -Umailer_db_user mailer -c 'select * from $i;'"
  done
}

parse_command() {
  local command=$1
  case $command in
  -h | --help | help)
    print_usage
    exit
    ;;
  start)
    start
    exit
    ;;
  stop)
    stop
    exit
    ;;
  test)
    test_checkout
    exit
    ;;
  database)
    checkout_db
    payment_db
    mailer_db
    exit
    ;;
  *)
    echo "$BASENAME: '$command' is not a $BASENAME command."
    echo "Run '$BASENAME --help' for more information."
    exit 1
    ;;
  esac
}

if [ -z "$1" ]; then
  print_usage
else
  parse_command "$1"
fi

