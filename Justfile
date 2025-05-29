test:
  bundle exec standardrb
  bundle exec rake test

build: test
  docker run -v "$PWD:/mnt/w" -w /mnt/w \
    -t ghcr.io/tamatebako/tebako-ubuntu-20.04:latest \
    tebako press -t /mnt/w/.tebako.yml
