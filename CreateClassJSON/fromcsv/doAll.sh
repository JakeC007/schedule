#!/bin/bash
# In LOffice, find , and replace with ; to not mess with csv. Eventually implement proper csv
# -e ... from the man page. 124 = ascii "|" as the delim (hopefully no conflicts). If there is a conflict, it will 'quote' it but use 94 = ascii "^". So I check if that exists (in makeJSON), in which case there is a conflict with "|" so needs to be manually fixed (assuming to "^" conflict).
#TODO can add true csv parsing, would be easy with a nodejs npm but this is fast

#Verbose for debugging, set =1 if want to see more printline echoing (crontab
#emails all echoed stdout so want to keep to a minumum)
VERBOSE=0
URL="https://www.swarthmore.edu/sites/default/files/assets/documents/registrar/201804CSV.xls"

if [ $VERBOSE -eq 1 ]; then
    echo "Hardcoded URL: $URL"
fi

SCRAPED_URL="$(curl --silent https://www.swarthmore.edu/registrar/course-schedule-pdfs |grep 'course_schedule_current.pdf'|grep -oP 'href="[A-Za-z0-9\-\/\.]*xls"'|sed 's/href="//g'|sed 's/"//g')"

if [ $VERBOSE -eq 1 ]; then
    echo "Output of scraping: '$SCRAPED_URL'"
fi

if [[ $SCRAPED_URL == *"xls"*  ]]; then
    URL="https://www.swarthmore.edu/$SCRAPED_URL"
    if [ $VERBOSE -eq 1 ]; then
        echo "Scraped url has xls, assumed to work: $URL"
    fi
fi

#Add my path so jq will work with crontabs
PATH=$HOME/bin:$PATH
wget --quiet -O schedule.tmp.xls  $URL 
diff schedule.tmp.xls schedule.xls
rv=$?
#Needs to be right after the diff $? returns the prev command's return value
if [ $rv -ne 0 ]; then
    echo "There is a new schedule"
    #So cp the newOne as a named file...
    DATE=$(date +"%Y%m%d")
    #Copy pdf for posterity and records/debugging. Seems to always be this URL?
    wget  --quiet -O PREV_SCHEDULES/$DATE.pdf http://www.swarthmore.edu/sites/default/files/assets/documents/registrar/course_schedule_current.pdf

    cp schedule.tmp.xls PREV_SCHEDULES/$DATE.xls
    cp schedule.js PREV_SCHEDULES/$DATE.js

    mv schedule.tmp.xls schedule.xls

    #And make the new out.json
    #If want to use unoconv:
    #unoconv -f csv -e FilterOptions=124,94,76 schedule.xls;
    #But this works as well and doesn't have a large loffice dependency (for gwaihir):
    python xlsToCSV.py

    ./makeJSON.js
    #Copy schedule into the website's js
    cp schedule.js ../../js

    #https://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
    #Only `mail`s the diff to me if I have mail (i.e. on the sccs server)

    #Beware, will send from atypical address which goes to spam
    command -v mail >/dev/null 2>&1 && { echo >&2 
    diff -wd <(jq -S . schedule.json) <(cat PREV_SCHEDULES/$DATE.js|sed "s/var classSchedObj = //"|jq -S .)|mail -s "Change in Class Schedule" staff@sccs.swarthmore.edu
}

else
    #Don't echo so cron doesn't email me
    if [ $VERBOSE -eq 1 ]; then
        echo "The downloaded schedule xls is the same as prev. Ending"
    fi
    rm schedule.tmp.xls;
fi
