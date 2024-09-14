#!/bin/bash

########### Set all the inputs in this section ###########
DPHOST=DATAPOWER_HOSTNAME_HERE
USERNAME=ADMIN_USERNAME_HERE
PASS=PASSWORD_HERE
BACKUP_DESTINATION=temporary:///secure-backup
INCLUDE_RAID='off'
CERTIFICATE_NAME=secure-backup-crypto-sscert.pem
PRIVATE_KEY_NAME=secure-backup-crypto-privkey.pem
##########################################################

################ UPLOAD_SECURE_BACKUP_CERT ##########################
## PLEASE HAVE KEY AND CERT IN THE SAME DIRECTORY AS THIS SCRIPT ##

readonly SOMA_URI="/service/mgmt/3.0"

sendSoma() {
    DP_HOST=$1
    HTTP_BODY=$2

    REQUEST="curl -k -X POST -u ${USERNAME}:${PASS} https://${DP_HOST}:5550${SOMA_URI} -d '${HTTP_BODY}'"
    echo "====================================================================================="
    echo "REQUEST: "$REQUEST
    RESPONSE=`curl -k -X POST -u $USERNAME:$PASS "https://${DP_HOST}:5550${SOMA_URI}" -d "${HTTP_BODY}"`
    echo "RESPONSE: "$RESPONSE
    if [[ "$RESPONSE" == *"Fault"* || "$RESPONSE" == *"error"* ]]; then
        echo "====================================================================================="
        echo "RESULT: Failure."
        exit
    else
        echo "====================================================================================="
        echo "RESULT: Success."
    fi
}

somaUploadFile() {
    DP_HOST=$1
    DOMAIN_NAME=$2
    DP_FOLDER=$3
    FILE_NAME=$4

    FILE_CONTENT_BASE64ENCODED=$(base64 $FILE_NAME)
    DEST_FILE_PATH=$DP_FOLDER/$FILE_NAME
    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-file name="$DEST_FILE_PATH">$FILE_CONTENT_BASE64ENCODED</dp:set-file>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Uploading file to" $DEST_FILE_PATH
    sendSoma $DP_HOST "${SOMA_REQ}"
}

somaUploadFile $DPHOST "default" "cert:///" $PRIVATE_KEY_NAME
somaUploadFile $DPHOST "default" "cert:///" $CERTIFICATE_NAME
###################################################################


############# START CREATING CERT AND SECURE BACKUP ###############

## The input file is created then used each time the SSH connection is made
INFILE=cli_input.txt

## Prefix of the output filename. It will have a date and timestamp added.
OUTFILE=cli_output.txt

##Generate the input file for the ssh cli to use
cat << EOF > $INFILE
$USERNAME
$PASS
co
crypto; certificate secure-backup-cert-object cert:///$CERTIFICATE_NAME; exit;
write mem;
y

secure-backup secure-backup-cert-object $BACKUP_DESTINATION "" $INCLUDE_RAID
EOF


## Create secure backup files
DATE=`date`

echo "Secure backup started at $DATE"
echo "Secure backup started at $DATE" > $OUTFILE

ssh -T $DPHOST < $INFILE  >> $OUTFILE

mkdir completed_logs
mv $OUTFILE completed_logs/$OUTFILE$(date +%Y%m%d-%H%M%S)
mv $INFILE completed_logs/$INFILE
echo "Created output file: " $OUTFILE$(date +%Y%m%d-%H%M%S)

echo "Complete"
