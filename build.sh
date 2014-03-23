#!/bin/bash

user=$1
pubkey=$2
if test -z $user ; then
  echo "Usage: $(basename $0) <username> <pubkey>" 2> /dev/null
  exit 1
fi

base_image=jumanjiman/booga

cat > data <<EOF
FROM   busybox
RUN    mkdir -p /home/user
VOLUME ["/home/user"]
CMD    ["/bin/true"]
EOF

# build new data image and remove intermediate containers
docker rmi data 2> /dev/null
cat data | docker build --rm -t data -

# create tiny data container named $user-data
docker rm $user-data 2> /dev/null
docker run -v /home/user --name $user-data busybox true

# remove the data image since we no longer need it
docker rmi data

# add contents of /etc/skel into data container
docker run --rm --volumes-from $user-data -u root $base_image cp /etc/skel/.bash* /home/user

# fix ownership of homedir
docker run --rm --volumes-from $user-data -u root $base_image chown -R user:user /home/user

# add ssh keys
docker run --rm --volumes-from $user-data -u user $base_image mkdir -p /home/user/.ssh
docker run --rm --volumes-from $user-data -u user $base_image chmod 0700 /home/user/.ssh
docker run --rm --volumes-from $user-data -u user $base_image /bin/bash -c "echo $pubkey > /home/user/.ssh/authorized_keys"
docker run --rm --volumes-from $user-data -u user $base_image chmod 0600 /home/user/.ssh/authorized_keys

# create a container from the user image
docker run -d -t --volumes-from $user-data -P -h wormhole.example.com --name $user-run $base_image