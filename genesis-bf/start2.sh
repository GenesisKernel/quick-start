#!/bin/sh

for i in $(seq 2 $1)
do
   sed 's/81/'8$i'/g' /etc/nginx/sites-available/default > /etc/nginx/sites-enabled/default$i
   sed -i -e 's/s1/s'$i'/g' /etc/nginx/sites-enabled/default$i
done

supervisorctl reread && supervisorctl update && supervisorctl restart nginx

