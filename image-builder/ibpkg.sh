#!/bin/bash
#
SEARCH=$1
LIMIT=100
CACHE=./ibpkg.cache
usage()
   {
   echo -e "\n   ibpkg -d {distro} -s \"search string\""
   echo -e "\n   ibpkg -l          # List available distributions\n"
   exit 1
} # end usage
missingsession()
   {
   echo -e "\n   \".access_token\" isn't set to a value.\n\n   Export IB_REFRESH_TOKEN to allow this script to authenticate to the \n   console.redhat.com website. API offline tokens can be generated at\n   https://access.redhat.com/management/api using the \"Generate Token\"\n   mechnanism.  These expire after 30 days."
} # end missingsession
findpkg()
   {
   mysession=$(curl --silent --request POST --data grant_type=refresh_token --data client_id=rhsm-api --data refresh_token=$IB_REFRESH_TOKEN https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token | jq -r .access_token)
   curl -X 'GET' --silent --header "Authorization: Bearer $mysession" --header "Content-Type: application/json" "https://console.redhat.com/api/image-builder/v1/packages?distribution=${DISTRO}&architecture=x86_64&search=${SEARCH}&limit=${LIMIT}&offset=0" > $CACHE
   if grep "502 Bad Gateway" $CACHE 1>/dev/null 2>/dev/null
      then
      echo -e "\nFound 0 packages.\n"
      exit 0
   elif grep "500 Internal Server Error" $CACHE 1>/dev/null 2>/dev/null
      then
      echo -e "\nIB_REFRESH_TOKEN is expired.  Get a new one https://access.redhat.com/management/api\n"
      exit 0
   fi
   COUNT=`jq -r '.meta.count' $CACHE | awk {'print $1'}`
   echo -e "\nFound $COUNT packages.\n"
   echo -e "RPMS@Description" >> ${CACHE}out
   jq -r '.data[] | [.name,.summary] | @csv' $CACHE >> ${CACHE}out
   cat ${CACHE}out | sed 's[","[@[' | sed 's["[[g' | column -t -s@
   echo ""
   rm -f $CACHE ${CACHE}out
   exit 0
} # end findpkg
distrolist()
   {
   mysession=$(curl --silent --request POST --data grant_type=refresh_token --data client_id=rhsm-api --data refresh_token=$IB_REFRESH_TOKEN https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token | jq -r .access_token)
   echo ""
   if ! grep Distribution ${CACHE}out 1>/dev/null 2>/dev/null
      then
      echo -e "Distribution@Description" >> ${CACHE}out
   fi
   curl --silent --header "Authorization: Bearer $mysession" https://console.redhat.com/api/image-builder/v1/distributions > $CACHE
   if grep "502 Bad Gateway" $CACHE 1>/dev/null 2>/dev/null
      then
      echo -e "\nFound 0 distributions.\n"
      exit 0
   elif grep "500 Internal Server Error" $CACHE 1>/dev/null 2>/dev/null
      then
      echo -e "IB_REFRESH_TOKEN is expired.  Get a new one https://access.redhat.com/management/api\n"
      exit 0
   fi
   cat $CACHE | jq -r '.[] | [.name, .description] | @csv' | sort -ur >> ${CACHE}out
   cat ${CACHE}out | sed 's[","[@[' | sed 's["[[g' | column -t -s@
   echo ""
   rm -f ${CACHE}out
   exit 0
} # end distrolist
if [ -z "$IB_REFRESH_TOKEN" ]
   then
   missingsession
   usage
fi
token="$IB_REFRESH_TOKEN"
while getopts ld:s: OPTION
   do
   case "$OPTION" in
      s) SEARCH=$OPTARG ;;
      d) DISTRO=$OPTARG ;;
      l) DISCO=TIME     ;;
      h) usage          ;;
      ?) usage          ;;
   esac
done
if [ -n "$DISCO" ]
   then
   distrolist
elif [ -z "$DISTRO" ]
   then
   usage
elif [ -z "$SEARCH" ]
   then
   usage
else
   findpkg "$SEARCH" "$DISTRO"
fi