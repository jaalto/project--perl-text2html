# .......................................................................
#
#   $Id: admin.bashrc,v 1.14 2004/04/05 10:17:37 jaalto Exp $
#
#   These bash functions will help uploading files to Sourceforge project.
#   You need:
#
#       Unix        (Unix)  http://www.fsf.org/directory/bash.html
#                   (Win32) http://www.cygwin.com/
#       Perl 5.4+   (Unix)  http://www.perl.org
#                   (Win32) http://www.ativestate.com
#       t2html.pl   Perl program to convert text -> HTML
#                   http://www.cpan.org/modules/by-authors/id/J/JA/JARIAALTO/
#
#
#   This file is of interest only for the Admin or Co-Developer of
#   project.
#
#       http://sourceforge.net/projects/perl-text2html
#       http://perl-text2html.sourceforge.net/
#
#   Include this file to your $HOME/.bashrc and make the necessary
#   modifications:
#
#       SF_PERL_TEXT2HTML_USER=<sourceforge-login-name>
#       SF_PERL_TEXT2HTML_USER_NAME="FirstName LastName"
#       SF_PERL_TEXT2HTML_EMAIL=<email address>
#       SF_PERL_TEXT2HTML_ROOT=~/cvs-projects/perl-text2html
#       SF_PERL_TEXT2HTML_HTML_TARGET=http://perl-text2html.sourceforge.net/
#
#       source ~/sforge/devel/perl-text2html/bin/admin.bashrc
#
# .......................................................................

function sfperl2htmlinit ()
{
    local id="sfperl2htmlinit"

    local url=http://perl-text2html.sourceforge.net/

    SF_UPLOAD_DIRECTORY=ftp://upload.sourceforge.net/incoming

    SF_PERL_TEXT2HTML_PROGRAM="t2html.pl"

    SF_PERL_TEXT2HTML_KWD=${SF_PERL_TEXT2HTML_KWD:-"\
Perl, HTML, CSS2, conversion, text2html"}
    SF_PERL_TEXT2HTML_DESC=${SF_PERL_TEXT2HTML_DESC:-"Perl text2html converter"}
    SF_PERL_TEXT2HTML_TITLE=${SF_PERL_TEXT2HTML_TITLE:-"$SF_PERL_TEXT2HTML_DESC"}


    if [ "$SF_PERL_TEXT2HTML_USER" = "" ]; then
       echo "$id: Identity SF_PERL_TEXT2HTML_USER unknown."
    fi


    if [ "$SF_PERL_TEXT2HTML_USER_NAME" = "" ]; then
       echo "$id: Identity SF_PERL_TEXT2HTML_USER_NAME unknown."
    fi

    if [ "$SF_PERL_TEXT2HTML_EMAIL" = "" ]; then
       echo "$id: Address SF_PERL_TEXT2HTML_EMAIL unknown."
    fi
}



function sfperl2htmldate ()
{
    date "+%Y.%m%d"
}

function sfperl2htmlfilesize ()
{
    #   put line into array ( .. )

    local line
    line=($(ls -l "$1"))

    #   Read 4th element from array
    #   -rw-r--r--    1 root     None         4989 Aug  5 23:37 file

    echo ${line[4]}
}


function sfperl2html_ask ()
{
    #   Ask question from user. RETURN answer is "no".

    local msg="$1"
    local answer
    local junk

    echo "$msg" >&2
    read -e answer junk

    case $answer in
        Y|y|yes)    return 0 ;;
        *)          return 1 ;;
    esac
}


function sfperl2htmlscp ()
{

    #   To upload file to project, call from shell prompt
    #
    #       bash$ sfperl2htmlscp <FILE>

    local sfuser=$SF_PERL_TEXT2HTML_USER
    local sfproject=p/pe/perl-text2html

    if [ "$SF_PERL_TEXT2HTML_USER" = "" ]; then
        echo "sfperl2htmlscp: identity SF_PERL_TEXT2HTML_USER unknown, can't scp files."
        return
    fi

    scp $* $sfuser@shell.sourceforge.net:/home/groups/$sfproject/htdocs/
}

function sfperl2html_html ()
{
    local id="sfperl2html_html"

    #   To generate HTML documentation located in /doc directory, call
    #
    #       bash$ sfperl2html_html <FILE.txt>
    #
    #   To generate Frame based documentation
    #
    #        bash$ sfperl2html_html <FILE.txt> --html-frame
    #
    #   For simple page, like README.txt
    #
    #        bash$ sfperl2html_html <FILE.txt> --as-is


    local input="$1"

    if [ "$input" = "" ]; then
        echo "Usage:   $id FILE [html-options]"
        return
    fi

    if [ ! -f "$input" ]; then
        echo "$id: No file found [$input]"
        return
    fi



    local opt

    if [ "$2" != "" ]; then
        opt="$2"
    fi

    echo "$id: Htmlizing $input $opt $size"

    perl -S $SF_PERL_TEXT2HTML_PROGRAM                          \
          $opt                                                  \
          --title  "$SF_PERL_TEXT2HTML_TITLE"                   \
          --author "$SF_PERL_TEXT2HTML_USER_NAME"               \
          --email  ""						\
          --meta-keywords "$SF_PERL_TEXT2HTML_KWD"              \
          --meta-description "$SF_PERL_TEXT2HTML_DESC"          \
          --name-uniq                                           \
          --Out                                                 \
          $input

    if [ -d "../../html/"  ]; then
        mv *.html ../../html/
    elif [ -d "../html/"  ]; then
        mv *.html ../html/
    else
        echo "$id: Can't move generated HTML to ../html/"
    fi


}

function sfperl2html_htmlall ()
{
    local id="sfperl2html_htmlall"

    #   loop all *.txt files and generate HTML
    #   If filesize if bigger than 15K, generate Framed HTML page.

    local dir=$SF_PERL_TEXT2HTML_ROOT/doc/txt

    (
        cd $dir || return
        echo "Source dir:" $(pwd)

        for file in *.txt;
        do
             local size=$(sfperl2htmlfilesize $file)

             if [ $size -gt 15000 ]; then
               opt=--html-frame
             fi

             sfperl2html_html $file $opt
         done

         echo "$id: All HTML generated"
    )

}


function sfperl2html_manual ()
{
    #   Generate documentation for the program binary

    local id="sfperl2html_manual"
    local dir=$SF_PERL_TEXT2HTML_ROOT

    if [ ! -d "$dir" ]; then
       echo "$id: invalid SF_PERL_TEXT2HTML_ROOT"
       return
    fi

    (
        cd $dir/bin

        for file in *.pl
        do
            base=${file%%.*}
            out=../doc/txt/$base.1
            echo "$id: Making $out"
            perl $file --help-man  > $out

            out=../doc/html/$base.html
            echo "$id: Making $out"

            perl $file --help-html > $out

        done

        #   The Perl POD maker leaves behind .x~~ files. Delete them

        for file in *~
        do
            rm $file
        done
    )

    echo "$id: Documentation updated."
}

function sfperl2html_docexamples1 ()
{
    local cmd="$1"
    local out="$2"

    echo "$cmd > $out"
    $cmd > $out
}

function sfperl2html_docexamples ()
{
    #   Generate documentation for examples

    local id="sfperl2html_docexamples"
    local dir=$SF_PERL_TEXT2HTML_ROOT

    if [ ! -d "$dir" ]; then
       echo "$id: invalid SF_PERL_TEXT2HTML_ROOT"
       return
    fi

    local out
    local cmd
    local file=t2html.pl
    local source=$file-1.txt
    local dest="../html"


    (
        cd $dir/doc/examples

        echo "cd " $(pwd)

       cmd="perl -S $file --css-font-normal $source"
       out=$dest/$file-1.html
       sfperl2html_docexamples1  "$cmd" "$out"


       cmd="perl -S $file --css-font-readable $source"
       out=$dest/$file-2.html
       sfperl2html_docexamples1  "$cmd" "$out"


       cmd="perl -S $file --html-frame --Out-dir $dest $file-3.txt"
       echo "$cmd"
       $cmd



        cmd="perl -S $file --css-code-bg --css-code-note=Note: \
$source"
        out=$dest/$file-4.html
        sfperl2html_docexamples1  "$cmd" "$out"


        #    Copy the original source file

        cmd="cp $source $dest"
        echo $cmd
        $cmd
    )

    echo "$id: Example documentation updated."
}



function sfperl2html_release_check ()
{
    #   Remind that that everything has been prepared
    #   Before doing release

    if sfperl2html_ask 'Run cvs -nq up (y/[n])?'
    then
        echo "Running..."
        ( cd $SF_PERL_TEXT2HTML_ROOT && cvs -nq up )
    fi


    if sfperl2html_ask '[sfperl2html_manual] Generate manuals (y/[n])?'
    then
        echo "Running..."
        sfperl2html_manual
    fi

    if sfperl2html_ask '[sfperl2html_docexamples] Generate examples (y/[n])?'
    then
        echo "Running..."
        sfperl2html_docexamples
    fi

}

function sfperl2html_release ()
{
    local id="sfperl2html_release"

    local dir=/tmp

    if [ ! -d $dir ]; then
        echo "$id: Can't make release. No directory [$dir]"
        return
    fi

    if [ ! -d "$SF_PERL_TEXT2HTML_ROOT" ]; then
        echo "$id: No SF_PERL_TEXT2HTML_ROOT [$SF_PERL_TEXT2HTML_ROOT]"
        return
    fi

    sfperl2html_release_check

    local opt=-9
    local cmd=gzip
    local ext1=.tar
    local ext2=.gz

    local base=perl-text2html
    local ver=$(sfperl2htmldate)
    local tar="$base-$ver$ext1"
    local file="$base-$ver$ext1$ext2"

    if [ -f $dir/$file ]; then
        echo "$id: Removing old archive $dir/$file"
        rm $dir/$file
    fi


    (

        local todir=$base-$ver
        local tmp=$dir/$todir

        if [ -d $tmp ]; then
            echo "$id: Removing old archive directory $tmp"
            rm -rf $tmp
        fi

        cp -r $SF_PERL_TEXT2HTML_ROOT $dir/$todir

        cd $dir

        find $todir -type f                     \
            \( -name "*[#~]*"                   \
               -o -name ".*[#~]"                \
               -o -name ".#*"                   \
               -o -name "*elc"                  \
               -o -name "*tar"                  \
               -o -name "*gz"                   \
               -o -name "*bz2"                  \
               -o -name .cvsignore              \
            \) -prune                           \
            -o -type d \( -name CVS \) -prune   \
            -o -type f -print                   \
            | xargs tar cvf $dir/$tar

        echo "$id: Running $cmd $opt $dir/$tar"

        $cmd $opt $dir/$tar

        echo "$id: Made release $dir/$file"
        ls -l $dir/$file
    )

    echo "$id: Call ncftpput upload.sourceforge.net /incoming $dir/$file"

}

sfperl2htmlinit                        # Run initializer


export SF_PERL_TEXT2HTML_KWD
export SF_PERL_TEXT2HTML_DESC
export SF_PERL_TEXT2HTML_TITLE
export SF_PERL_TEXT2HTML_PROGRAM
export SF_UPLOAD_DIRECTORY

# End of file
