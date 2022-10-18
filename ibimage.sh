#!/bin/bash
#
SEARCH=$1
LIMIT=100
CACHE=./ibimage.cache
usage()
   {
   echo -e "\n   ibimage -d {image} # List full details of an image"
   echo -e "\n   ibimage -l         # List images\n"
   exit 1
} # end usage
missingsession()
   {
   echo -e "\n   \".access_token\" isn't set to a value.\n\n   Export IB_REFRESH_TOKEN to allow this script to authenticate to the \n   console.redhat.com website. API offline tokens can be generated at\n   https://access.redhat.com/management/api using the \"Generate Token\"\n   mechnanism.  These expire after 30 days."
} # end missingsession
imagelist()
   {
   mysession=$(curl --silent --request POST --data grant_type=refresh_token --data client_id=rhsm-api --data refresh_token=$IB_REFRESH_TOKEN https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token | jq -r .access_token)
   curl --silent --header "Authorization: Bearer $mysession" --header "Content-Type: application/json" "https://console.redhat.com/api/image-builder/v1/composes" > $CACHE
   if grep "502 Bad Gateway" $CACHE 1>/dev/null 2>/dev/null
      then
      echo -e "\nNo images found.\n"
      exit 0
   fi
   echo ""
   echo -e "Image ID@Distribution@Image Name@Created" >> ${CACHE}out
   jq -r '.data[] | [.id,.request.distribution,.image_name,.created_at] | @csv' $CACHE >> ${CACHE}out
   cat ${CACHE}out | sed 's[","[@[g' | sed 's["[[g' | column -t -s@
   echo ""
   rm -f $CACHE ${CACHE}out
   exit 0
} # end imagelist
findimage()
   {
   mysession=$(curl --silent --request POST --data grant_type=refresh_token --data client_id=rhsm-api --data refresh_token=$IB_REFRESH_TOKEN https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token | jq -r .access_token)
   echo ""
   CHECK=`echo "d272f296-cbe5-4e27-8a46-08428b39bafa" | wc -c | awk {'print $1'}`
   case $CHECK in
      37) curl --silent --header "Authorization: Bearer $mysession" --header "Content-Type: application/json" "https://console.redhat.com/api/image-builder/v1/composes/${IMAGE}" > $CACHE
          if grep "502 Bad Gateway" $CACHE 1>/dev/null 2>/dev/null
             then
             echo -e "\nNo image found.\n"
             exit 0
          fi
          echo -e "Image ID@$IMAGE" >> ${CACHE}out
          echo -e "Image Status@\c" >> ${CACHE}out
          jq  -r '[.image_status.status] | @tsv' $CACHE >> ${CACHE}out
          echo -e "Upload Status@\c" >> ${CACHE}out
          jq  -r '[.image_status.upload_status.status] | @tsv' $CACHE >> ${CACHE}out
          TYPE=`jq  -r '[.image_status.upload_status.type] | @tsv' $CACHE`
          echo -e "Image Type@$TYPE" >> ${CACHE}out
          case $TYPE in
              gcp) echo -e "Project ID@\c" >> ${CACHE}out
                   jq  -r '[.image_status.upload_status.options.project_id] | @tsv' $CACHE >> ${CACHE}out
                   echo -e "Project Image@\c" >> ${CACHE}out
                   jq  -r '[.image_status.upload_status.options.image_name] | @tsv' $CACHE >> ${CACHE}out
                   ;;
            azure) echo -e "Azure Image@\c" >> ${CACHE}out
                   jq  -r '[.image_status.upload_status.options.image_name] | @tsv' $CACHE >> ${CACHE}out
                   ;;
          esac
          cat ${CACHE}out | sed 's[","[@[' | sed 's["[[g' | column -t -s@
          echo ""
          ;;
       *) echo -e "\nImage ID's are 32 alphanumerics separated by 5 dashes.\n"
          exit 1
          ;;
   esac
   rm -f ${CACHE}out
   exit 0
} # end findimage
if [ -z "$IB_REFRESH_TOKEN" ]
   then
   missingsession
   usage
fi
token="$IB_REFRESH_TOKEN"
while getopts ld: OPTION
   do
   case "$OPTION" in
      d) IMAGE=$OPTARG ;;
      l) DISCO=TIME     ;;
      h) usage          ;;
      ?) usage          ;;
   esac
done
if [ -n "$DISCO" ]
   then
   imagelist
elif [ -n "$IMAGE" ]
   then
   findimage "$IMAGE"
fi
usage