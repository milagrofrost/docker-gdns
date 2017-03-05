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
  echo "Using IPV4 for updates"
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

  IP4_CURRENT=
  IP6_CURRENT=
  IP_HAS_CHANGED=

  gcloud dns record-sets transaction start -z="$ZONE" || { exit 1; }
  if [ -n "$domainList" ]; then
    while read -r line; do
      echo "Updating the entry:"
      echo "${line}"
      if [[ "$TYPE" = "A" ]]; then
        IP4_CURRENT="${line}"
      fi
      if [[ "$TYPE" = "AAAA" ]]; then
        IP6_CURRENT="${line}"
      fi
    done <<< "$domainList"
  else
    echo "Entries do not exist, so will creat only new entries"
  fi

  # Add transactions
  if [ "$IPV4" = "yes" ]; then
    NAME=$(echo ${IP4_CURRENT} | awk '{print $1}')
    TYPE=$(echo ${IP4_CURRENT} | awk '{print $2}')
    TTL=$(echo ${IP4_CURRENT} | awk '{print $3}')
    DATA=$(echo ${IP4_CURRENT} | awk '{print $4}')

    IP4=$(dig o-o.myaddr.l.google.com @ns1.google.com TXT +short | sed 's/"//g')
    echo "Old IPv4 was '${DATA}'"
    echo "New IPv4 address is '${IP4}'"
    if [[ "$DATA" != "$IP4" ]]; then
      if [ -n "$IP4_CURRENT" ]; then
        gcloud dns record-sets transaction remove --zone=${ZONE} --name="${NAME}" --type="${TYPE}" --ttl="${TTL}" ${DATA} || { gcloud dns record-sets transaction abort --zone=${ZONE}; exit 1; }
      fi
      gcloud dns record-sets transaction add --zone=${ZONE} --name="${DOMAIN}." --type="A" --ttl="300" ${IP4} || { gcloud dns record-sets transaction abort --zone=${ZONE}; exit 1; }
      IP_HAS_CHANGED="yes"
    else
      echo "IP4 are the same, not updating."
    fi
  fi

  if [ "$IPV6" = "yes" ]; then
    NAME=$(echo ${IP6_CURRENT} | awk '{print $1}')
    TYPE=$(echo ${IP6_CURRENT} | awk '{print $2}')
    TTL=$(echo ${IP6_CURRENT} | awk '{print $3}')
    DATA=$(echo ${IP6_CURRENT} | awk '{print $4}')

    #ip6=`ifconfig | grep inet6 | grep -i global | awk -F " " '{print $3}' | awk -F "/" '{print $1}'`
    IP6=`ip -6 addr | grep inet6 | awk -F '[ \t]+|/' '{print $3}' | grep -v ^::1 | grep -v ^fe80 | head -n 1`
    echo "Old IPv6 was '${DATA}'"
    echo "New IPv6 address is '${IP6}'"
    if [[ "$DATA" != "$IP6" ]]; then
      if [ -n "$IP6_CURRENT" ]; then
        gcloud dns record-sets transaction remove --zone=${ZONE} --name="${NAME}" --type="${TYPE}" --ttl="${TTL}" ${DATA} || { gcloud dns record-sets transaction abort --zone=${ZONE}; exit 1; }
      fi
      gcloud dns record-sets transaction add --zone=${ZONE} --name="${DOMAIN}." --type="AAAA" --ttl="300" ${IP6} || { gcloud dns record-sets transaction abort --zone=${ZONE}; exit 1; }
      IP_HAS_CHANGED="yes"
    else
      echo "IP6 are the same, not updating."
    fi
  fi

  # Execute transaction
  if [[ "$IP_HAS_CHANGED" = "yes" ]]; then
    gcloud dns record-sets transaction execute --zone=${ZONE} || { gcloud dns record-sets transaction abort --zone=${ZONE}; exit 1; }
  else
    echo "IP has not changed, aborting transaction."
    gcloud dns record-sets transaction abort --zone=${ZONE}
  fi

  sleep $INTERVAL
done
