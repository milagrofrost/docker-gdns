#!/bin/bash

# Search for custom config file, if it doesn't exist, copy the default one
if [ ! -f /config/gdns.conf ]; then
  echo "Creating config file. Please do not forget to enter your domain and token info on gdns.conf"
  cp /root/gdns/gdns.conf /config/gdns.conf
  chmod a+w /config/gdns.conf
  exit 1
fi

tr -d '\r' < /config/gdns.conf > /tmp/gdns.conf

. /tmp/gdns.conf

if [ -z "$DOMAIN" ]; then
  echo "DOMAIN must be defined in gdns.conf"
  exit 1
elif [ "$DOMAIN" = "yourdomain" ]; then
  echo "Please enter your domain in gdns.conf"
  exit 1
fi

if [ -z "$INTERVAL" ]; then
  INTERVAL='30m'
fi

if [ -z "$IPV4" ]; then
  IPV4='no'
elif [ "$IPV4" = "yes" ]; then
  echo "Using IPV6 for updates"
else
  echo "For IPv4, please use IPV4=yes in gdns.conf"
  IPV4='no'
fi

if [ -z "$IPV6" ]; then
  IPV6='no'
elif [ "$IPV6" = "yes" ]; then
  echo "Using IPV6 for updates"
else
  echo "For IPv6, please use IPV6=yes in gdns.conf"
  IPV6='no'
fi

if [[ ! "$INTERVAL" =~ ^[0-9]+[mhd]$ ]]; then
  echo "INTERVAL must be a number followed by m, h, or d. Example: 5m"
  exit 1
fi

if [[ "${INTERVAL: -1}" == 'm' && "${INTERVAL:0:-1}" -lt 5 ]]; then
  echo "The shortest allowed INTERVAL is 5 minutes"
  exit 1
fi

if [ -n "$GCLOUD_AUTH" ]; then
  authFile=/root/gdns/auth.json
  type openssl >/dev/null 2>&1 || { echo >&2 "I require openssl but it's not installed.  Aborting."; exit 1; }
  echo ${GCLOUD_AUTH} | openssl enc -base64 -d > ${authFile} || exit 1
  gcloud auth activate-service-account --key-file="${authFile}" ${GCLOUD_ACCOUNT} || exit 1
elif [ -n "$GCLOUD_AUTH_FILE" ]; then
  authFile=/config/${GCLOUD_AUTH_FILE}
  gcloud auth activate-service-account --key-file="${authFile}" ${GCLOUD_ACCOUNT} || exit 1
else
  echo "No auth file provided, please read README"
  exit 1
fi

gcloud config set project ${GCLOUD_PROJECT}

#-----------------------------------------------------------------------------------------------------------------------

function ts {
  echo [`date '+%b %d %X'`]
}

IPCMD=ip
# ip -6 addr | grep inet6 | awk -F '[ \t]+|/' '{print $3}' | grep -v ^::1 | grep -v ^fe80 | head -n 1
# ifconfig | grep inet6 | grep -i global | awk -F " " '{print $3}' | awk -F "/" '{print $1}'

type $IPCMD >/dev/null 2>&1 || { echo >&2 "I require $IPCMD but it's not installed.  Aborting."; exit 1; }



#-----------------------------------------------------------------------------------------------------------------------

while true
do

  # Obtain domain lists
  domainList=$(gcloud dns record-sets list --zone ${ZONE} | grep ^${DOMAIN})

  gcloud dns record-sets transaction start -z="$ZONE" || exit 1
  if [ -n "$domainList" ]; then
    echo "Updating the entries:"
    echo ${domainList}
    for line in ${domainList}
    do
      NAME=$(echo $line | awk '{print $1}')
      TYPE=$(echo $line | awk '{print $2}')
      TTL=$(echo $line | awk '{print $3}')
      DATA=$(echo $line | awk '{print $4}')
      gcloud dns record-sets transaction remove --zone=${ZONE} --name="${NAME}" --type="${TYPE}" --ttl="${TTL}" ${DATA} || gcloud dns record-sets transaction abort; exit 1
    done
  else
    echo "Entries do not exist, so will creat only new entries"
  fi

  # Add transactions
  if [ "$IPV4" = "yes" ]; then
    IP4=$(dig o-o.myaddr.l.google.com @ns1.google.com TXT +short)
    echo "IPv4 address is ${IP4}"
    gcloud dns record-sets transaction add --zone=${ZONE} --name="${DOMAIN}." --type="A" --ttl="300" ${IP4} || gcloud dns record-sets transaction abort; exit 1
  fi

  if [ "$IPV6" = "yes" ]; then
    #ip6=`ifconfig | grep inet6 | grep -i global | awk -F " " '{print $3}' | awk -F "/" '{print $1}'`
    IP6=`ip -6 addr | grep inet6 | awk -F '[ \t]+|/' '{print $3}' | grep -v ^::1 | grep -v ^fe80 | head -n 1`
    echo "IP address is ${IP6}"
    gcloud dns record-sets transaction add --zone=${ZONE} --name="${DOMAIN}." --type="AAAA" --ttl="300" ${IP6} || gcloud dns record-sets transaction abort; exit 1
  fi

  # Execute transaction
  gcloud dns record-sets transaction execute --zone=${ZONE} || gcloud dns record-sets transaction abort; exit 1


  sleep $INTERVAL
done
