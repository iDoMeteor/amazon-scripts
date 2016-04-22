
#!/bin/bash -
#===============================================================================
#
#          FILE: meteor-bundle-and-send
#
#         USAGE: meteor-bundle-and-send -b bundle-name -u user -s server [-i keyfile.pem] [-v]
#                meteor-bundle-and-send --bundle bundle-name --user user --server server [--key keyfile.pem] [--verbose]
#
#   DESCRIPTION:
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (),
#  ORGANIZATION:
#       CREATED: 04/12/2016 12:09
#      REVISION:  ---
#===============================================================================

# Exit on failure and treat unset variables as an error
set -e
set -o nounset

# Run function
function run()
{
  echo "Running: $@"
  "$@"
}

# Parse command line arguments into variables
while :
do
    case "$1" in
      -b | --bundle)
    BUNDLE="$2"
    shift 2
    ;;
      -i | --key)
    KEYFILE=$2
    shift 2
    ;;
      -s | --server)
    SSL=true
    shift 1
    ;;
      -u | --user)
    USER="$2"
    shift 2
    ;;
      -v | --verbose)
    VERBOSE=true
    shift 1
    ;;
      -*)
    echo "Error: Unknown option: $1" >&2
    exit 1
    ;;
      *)  # No more options
    break
    ;;
    esac
done

# Validate required arguments

# Check for verbosity
if $VERBOSE ; then
  set -v
fi

# Check for keyfile
if [[ -f $KEYFILE ]]; then
  KEYARG="-i $KEYFILE"
else
  KEYARG=
fi

run /usr/local/bin/meteor bundle ../$BUNDLE.tar.gz
run scp $KEYARG ../$BUNDLE.tar.gz $SERVER:www/
run scp $KEYARG scripts/meteor-unbundle-and-deploy.sh $SERVER:
run ssh $KEYARG $SERVER bash meteor-unbundle-and-deploy.sh -b $BUNDLE

# End
echo "Local tasks complete.  App has been deployed and Passenger process re-started."
exit 0
