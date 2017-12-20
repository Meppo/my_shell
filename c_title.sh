#!/bin/bash

echo "#!/bin/bash" > /tmp/c.sh
echo "PROMPT_COMMAND='printf \"\\033]0;%s\\007\" \"$1\" '" >> /tmp/c.sh
chmod +x /tmp/c.sh
source /tmp/c.sh
#PROMPT_COMMAND="'printf \"\\033]0;%s\\007\" ' \"$1\" '"
