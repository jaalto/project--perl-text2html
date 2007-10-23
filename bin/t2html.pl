#!/usr/bin/perl
#
# t2html -- Perl, text2html converter. Uses Techical text format (TF)
#
# {{{ Documentation
#
#  File id
#
#       Copyright (C) 1996-2007 Jari Aalto
#
#       This program is free software; you can redistribute it and/or
#       modify it under the terms of the GNU General Public License as
#       published by the Free Software Foundation; either version 2 of
#       the License, or (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful, but
#       WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#       General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with program. If not, write to the
#       Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#       Boston, MA 02110-1301, USA.
#
#       Visit <http://www.gnu.org/copyleft/gpl.html>
#
#   Introduction
#
#       Please start this perl script with option
#
#           --help      to get the help page
#
#   Description
#
#       This perl program converts text files that are written in rigid
#       (T)echnical layout (f)ormat (which is explained when you run --help)
#       to html pages very easily and effectively.
#
#       If you plan to put any text files available in HTML format you will
#       find this program a very useful. If you want to have fancy
#       graphics or more personal page layout, then this program is not for
#       you.
#
#       There is also Emacs package that helps you to write and format text
#       files to Technical format.
#
#           tinytf.el
#
#   Profiling results
#
#       Here are Devel::Dprof profiling results for 560k text file in HP-UX
#       Time in seconds is User time.
#
#           perl -d:DProf ./t2html page.txt > /dev/null
#
#           Time Seconds     #Calls sec/call Name
#           52.1   22.96      12880   0.0018 main::DoLine
#           8.31   3.660      19702   0.0002 main::IsHeading
#           5.72   2.520       9853   0.0003 main::XlatUrl
#           5.56   2.450       9853   0.0002 main::XlatMailto
#           5.22   2.300          1   2.3000 main::HandleOneFile
#           4.22   1.860       9853   0.0002 main::XlatHtml
#           4.06   1.790       9853   0.0002 main::IsBullet
#           3.18   1.400       9853   0.0001 main::XlatRef
#           1.77   0.780          1   0.7800 main::KillToc
#           1.43   0.630          1   0.6300 Text::Tabs::expand
#           1.09   0.480          1   0.4800 main::PrintEnd
#           0.61   0.270        353   0.0008 main::MakeHeadingName
#           0.57   0.250          1   0.2500 main::CODE(0x401e4fb0)
#           0.48   0.210          1   0.2100 LWP::UserAgent::CODE(0x4023394c)
#           0.41   0.180          1   0.1800 main::PrintHtmlDoc
#
#   Change Log: (none)

use 5.004;      # Prototypes were introduced in this perl version
use strict;

#       A U T O L O A D
#
#       The => operator quotes only words, and Pod::Text is not
#       Perl "word"

use autouse 'Carp'          => qw( croak carp cluck confess   );
use autouse 'Pod::Text'     => qw( pod2text                   );
use autouse 'Pod::Html'     => qw( pod2html                   );

#  Loaded only with --Help-man
#  use Pod::Man

use locale;
use Cwd;
use English;
use File::Basename;
use Getopt::Long;
use Text::Tabs;

IMPORT:             #   These are environment variables
{
    use Env;
    use vars qw
    (
        $HOME
        $TEMP
        $TEMPDIR
        $PATH
        $LANG
    );
}

    use vars qw ( $VERSION );

    #   This is for use of Makefile.PL and ExtUtils::MakeMaker
    #   So that it puts the tardist number in format YYYY.MMDD
    #   The REAL version number is defined later
    #
    #   The following variable is updated by Emacs setup whenever
    #   this file is saved. See Emacs module tinperl.el where the
    #   feature is implemented.

    $VERSION = '2007.1019.1708';

# }}}
# {{{ Initial setup

# ****************************************************************************
#
#   DESCRIPTION
#
#       Ignore HERE document indentation. Use function like this
#
#           @var = Here << "EOF";
#                   Indented text
#                   Indented text
#           EOF
#
#   INPUT PARAMETERS
#
#       none
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub Here ($)
{
    (my $str = shift) =~ s/^\s+//gm;
    $str
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Preserve first whitespace indentation. See Perl Cookbook 1.11 p.23
#
#   INPUT PARAMETERS
#
#       none
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub HereQuote ($)
{
    local $ARG = shift;

    my ( $white, $lead );

    if ( /^\s*(?:([^\w\s]+)(\s*).*\n)(?:\s*\1\2?.*\n)+$/ )     #font-lock s//
    {
        ( $white, $lead ) = ( $2, quotemeta $1);
    }
    else
    {
        ( $white, $lead ) = ( /^(\s+)/, '');
    }

    s/^\s*?$lead(?:$white)?//gm;

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Set global variables for the program
#
#   INPUT PARAMETERS
#
#       none
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub Initialize ()
{
    # ........................................... internal variables ...

    use vars qw
    (
        $HTTP_CODE_OK
        $LIB
        $PROGNAME
        $URL
        %HTML_HASH
        $debug
    );

    $PROGNAME   = "t2html";
    $LIB        = $PROGNAME;      # library where each function belongs: PRGNAME
    $URL        =  "http://freshmeat.net/projects/perl-text2html";

    $OUTPUT_AUTOFLUSH = 1;
    $HTTP_CODE_OK     = 200;

    # ................................ globals gathered when running ...

    use vars qw
    (
        @HEADING_ARRAY
        %HEADING_HASH
        %LINK_HASH
        %LINK_HASH_CODE
    );

    @HEADING_ARRAY  = ();
    %HEADING_HASH   = ();
    %LINK_HASH      = ();   # Links that are invalid: 'link' -- errCode
    %LINK_HASH_CODE = ();   # Error code table: errCode -- 'text'

    # .................................................... constants ...

    use vars qw
    (
        $OUTPUT_TYPE_SIMPLE
        $OUTPUT_TYPE_QUIET
        $OUTPUT_TYPE_UNDEFINED

        $BULLET_TYPE_NUMBERED
        $BULLET_TYPE_NORMAL
    );

    #   Some constants:  old Perl style. New Perl uses "use constant"
    #   I like these better, because you can use "$" in front of variables.
    #   With "use contant" you cannot use "$".

    *OUTPUT_TYPE_SIMPLE    = \-simple;
    *OUTPUT_TYPE_QUIET     = \-quiet;
    *OUTPUT_TYPE_UNDEFINED = \-undefined;

    *BULLET_TYPE_NUMBERED = \-numbered;
    *BULLET_TYPE_NORMAL   = \-normal;

    use vars qw( %COLUMN_HASH );

    %COLUMN_HASH =
    (
        "" => ""

        , beg7  => qq(<p class="column7"><em><strong>)
        , end7  => "</strong></em>"

        , beg9  => qq(<p class="column9"><strong>)
        , end9  => "</strong>"

        , beg10  => qq(<p class="column10"><em class="quote10">)
        , end10  => "</em>"

        , beg7quote => qq(<span class="quote7">)
        , end7quote => "</span>"

        , begemp  => qq(<em class="word">)
        , endemp  => "</em>"

        , begbold => qq(<strong class="word">)
        , endbold => "</strong>"

        , begquote => qq(<samp class="word">)
        , endquote => "</samp>"

        , begsmall => qq(<span class="word-small">)
        , endsmall => "</span>"

        , begbig  => qq(<span class="word-big">)
        , endbig  => "</span>"

        , begref  => qq(<span class="word-ref">)
        , endref  => "</span>"

        , superscriptbeg  => qq(<span class="super">)
        , superscriptend  => "</span>"

    );

    # ..................................................... language ...
    # There are some visible LANGUAGE dependent things which must
    # be changed. the internal HTML, NAMES and all can be in English.

    use vars qw( %LANGUAGE_HASH );

    %LANGUAGE_HASH =
    (
        -toc  =>
        {
              en => 'Table of Contents'     # U.S. English -- all caps
            , es => 'Tabla de Contenidos'
            , fi => 'Sis&auml;llysluettelo'
        },

       -pic   =>
       {
              en => 'Picture'
            , fi => 'Kuva'
            , de => 'Bilde'
       }
    );

    # .......................................................... dtd ...

    sub Here($);

    my $doctype = Here <<"EOF";
        <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
EOF

    my $doctype_frame = HereQuote <<"EOF";
        <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Frameset//EN"
                  "http://www.w3.org/TR/REC-html40/frameset.dtd">
EOF

    %HTML_HASH =
    (
        doctype         => $doctype
        , doctype_frame => $doctype_frame
        , beg           => "<html>"
        , end           => "</html>"
        , br            => "<br>"
        , hr            => "<hr>"
        , pbeg          => "<p>"
        , pend          => ""
    );

    # ............................................... css properties ...

    use vars qw
    (
        $CSS_BODY_FONT_TYPE_NORMAL
        $CSS_BODY_FONT_TYPE_READABLE
        $CSS_BODY_FONT_SIZE_FRAME
        $CSS_BODY_FONT_SIZE_NORMAL
    );

    $CSS_BODY_FONT_TYPE_NORMAL   = qq("Times New Roman", serif;);

    $CSS_BODY_FONT_TYPE_READABLE =
        qq(verdana, arial, helvetica, sans-serif;);

    $CSS_BODY_FONT_SIZE_FRAME    = qq(0.6em; /* relative, 8pt */);
    $CSS_BODY_FONT_SIZE_NORMAL   = qq(12pt; /* points */);

    # ............................................. run time globals ...

    use vars qw
    (
        $ARG_PATH
        $ARG_FILE
        $ARG_DIR
    );
}

# }}}

# {{{ Args parsing

# ************************************************************** &args *******
#
#   DESCRIPTION
#
#       Read command line options from file. This is necessary, because
#       many operating systems have a limit how long and how many options
#       can be passed in command line. The file can have "#" comments and
#       options spread on multiple lines.
#
#       Putting the options to separate file overcomes this limitation.
#
#   INPUT PARAMETERS
#
#       $file       File where the command line call is.
#
#   RETURN VALUES
#
#       @array      Like if you got the options via @ARGV
#
# ****************************************************************************

sub HandleCommandLineArgsFromFile ( $ )
{
    my $id = "$LIB.HandleCommandLineArgsFromFile";
    my ( $file ) = @ARG;

    local ( *FILE, $ARG );
    my ( @arr, $line );

    unless ( open FILE, $file )
    {
        die "$id: Cannot open file [$file] $ERRNO";
    }

    while ( defined($ARG = <FILE>) )
    {
        s/#\s.*//g;                 # Delete comments

        next if /^\s*$/;            # if empty line

        s/^\s+//;                   # trim leading and trailing spaces
        s/\s+$//;                   #font-lock s //

        $debug  and  warn "$id: ADD => $ARG\n";

        $line .= $ARG;
    }

    #   Now comes the difficult part, We can't just split()'
    #   Because thre may be options like
    #
    #       --autor "John doe"
    #
    #   Which soule beome as split()
    #
    #       --author
    #       "John
    #       Doe"
    #
    #   But it should really be two arguments
    #
    #       --author
    #       John doe

    $ARG = $line;

    while ( $ARG ne ""  )
    {
        s/^\s+//;

        if ( /^(-+\S+)(.*)/ )   #font-lock s//
        {
            $debug  and  warn "$id: PARSE option $1\n";

            push @arr, $1;
            $ARG = $2;
        }
        elsif ( /^[\"]([^\"]*)[\"](.*)/ )       #font-lock s//
        {
            $debug  and  warn "$id: PARSE dquote $1\n";

            push @arr, $1;
            $ARG = $2;
        }
        elsif ( /^'([^']*)'(.*)/ )      #font-lock s'/
        {
            $debug  and  warn "$id: PARSE squote $1\n";

            push @arr, $1;
            $ARG = $2;
        }
        elsif ( /^(\S+)(.*)/ )  #font-lock s//  #
        {
            $debug  and  warn "$id: PARSE value  $1\n";

            push @arr, $1;
            $ARG = $2;
        }
    }

    close FILE;

    @arr;
}

# ************************************************************** &args *******
#
#   DESCRIPTION
#
#       Read and interpret command line arguments
#
#   INPUT PARAMETERS
#
#       none
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub HandleCommandLineArgs ()
{
    my $id = "$LIB.HandleCommandLineArgs";
    local $ARG;

    $debug  and  print "$id: start\n";

    # ....................................... options but not globals ...
    #   The variables are defined in Getopt, but they are locally used
    #   only inside this fucntion

    my $deleteDefault;
    my $versionOption;

    # .......................................... command line options ...
    #   Global variables

    use vars qw
    (

        $AS_IS
        $AUTHOR
        $BASE
        $BASE_URL
        $BASE_URL_ALL
        $BUT_NEXT
        $BUT_PREV
        $BUT_TOP
        $CSS_CODE_STYLE
        $CSS_CODE_STYLE_ATTRIBUTES
        $CSS_CODE_STYLE_NOTE
        $CSS_FONT_SIZE
        $CSS_FONT_TYPE
        $DELETE_EMAIL
        $DELETE_REGEXP
        $DISCLAIMER_FILE
        $DOC
        $DOC_URL
        $FONT
        $FORGET_HEAD_NUMBERS
        $FRAME
        $HTML_BODY_ATTRIBUTES
        $JAVA_CODE
        $LANG_ISO
        $LINK_CHECK
        $LINK_CHECK_ERR_TEXT_ONE_LINE
        $META_DESC
        $META_KEYWORDS
        $NAME_UNIQ
        $OBEY_T2HTML_DIRECTIVES
        $OPT_AUTO_DETECT
        $OPT_EMAIL
        $OPT_HEADING_TOP_BUTTON
        $OUTPUT_AUTOMATIC
        $OUTPUT_DIR
        $OUTPUT_SIMPLE
        $OUTPUT_TYPE
        $PICTURE_ALT
        $PRINT
        $PRINT_NAME_REFS
        $PRINT_URL
        $QUIET
        $SCRIPT_FILE
        $SPLIT1
        $SPLIT2
        $SPLIT_NAME_FILENAMES
        $SPLIT_REGEXP
        $TITLE
        $XHTML_RENDER

        @CSS_FILE
        %REFERENCE_HASH

        $debug
        $time
        $verb
    );

    #   When heading string is read, forget the numbering by default
    #
    #       1.1 heading     --> "Heading"

    $FORGET_HEAD_NUMBERS = 1;

    #   When gathering toc jump points, NAME AHREF=""
    #
    #   NAME_UNIQ       if 1, then use sequential numbers for headings
    #   PRINT_NAME_REFS if 1, print to stderr the gathered NAME REFS.

    $NAME_UNIQ           = 0;
    $PRINT_NAME_REFS     = 0;
    $PICTURE_ALT         = 1;    # add ALT="picture 1" to images

    # ................................................... link check ...
    #   The LWP module is optional and we raise a flag
    #   if we were able to import it. See function CheckModuleLWP()
    #
    #   LINK_CHECK requires that LWP module is present

    use vars qw
    (
        $MODULE_LWP_OK
        $MODULE_LINKEXTRACTOR_OK
    );

    $MODULE_LWP_OK              = 0;
    $MODULE_LINKEXTRACTOR_OK    = 0;

    # ..................................................... language ...

    $LANG_ISO = "en";           # Standard ISO language name, two chars

    if ( defined $LANG and $LANG =~ /^[a-z][a-z]/i ) # s/ environment var
    {
        $LANG_ISO = lc $LANG;
    }

    # ......................................................... Other ...

    $debug  and  PrintArray("$id: before options-file", \@ARGV);

    $ARG = join ' ', @ARGV;

    if ( /(--options?-file(?:=|\s+)(\S+))/  )         # s/
    {
        my $opt  = $1;
        my $file = $2;
        my @argv;

        for my $arg ( @ARGV )               # Remove option
        {
            next if  $arg eq $opt;
            push @argv, $arg;
        }

        # Merge options

        @ARGV = ( @argv, HandleCommandLineArgsFromFile($file) );
    }

    my @argv = @ARGV;           # Save value for debugging;

    $debug  and  PrintArray("$id: after options-file", \@ARGV);

    # .................................................. column-args ...

    #   Remember that shell eats the double spaces.
    #   --html-column-beg="10 " -->
    #   --html-column-beg=10

    my ( $key, $tag, $val , $email );

    for ( @ARGV )
    {
        if ( /--html-column-(beg|end)/ )
        {
            if ( /--html-column-(beg|end)=(\w+) +(.+)/ )        #font-lock s//
            {
                ( $key, $tag, $val ) = ( $1, $2, $3);

                $COLUMN_HASH{ $key . $tag } = $val;
                $debug  and  warn "$key$tag ==> $val\n";
            }
            else
            {
                warn "Unregognized switch: $ARG";
            }
        }
    }

    @ARGV = grep ! /--html-column-/, @ARGV;

    $debug  and  PrintArray("$id: after for-loop checks", \@ARGV);

    $BASE  = "";

    my ( @reference , $referenceSeparator );
    my ( $fontNormal, $fontReadable, $linkCacheFile );
    my ( $help, $helpHTML, $helpMan, $version, $testpage, $code3d );
    my ( $codeBg, $codeBg2, $codeNote );

    # .................................................... read args ...

    # $Getopt::Long::debug = 1;

    Getopt::Long::config( qw
    (
        require_order
        no_ignore_case
        no_ignore_case_always
    ));

    $debug  and  PrintArray("$id: before GetOption", \@ARGV);

    #  The doubling quitet '-cw' check which would say
    #  Name "Getopt::DEBUG" used only once: possible typo at ...

    $Getopt::DEBUG = 1;

    GetOptions      # Getopt::Long
    (
          "debug:i"                 => \$debug
        , "d:i"                     => \$debug
        , "h|help"                  => \$help
        , "Help-html"               => \$helpHTML
        , "Help-man"                => \$helpMan
        , "test-page"               => \$testpage
        , "Version"                 => \$version
        , "verbose:i"               => \$verb

        , "Auto-detect"             => \$OPT_AUTO_DETECT
        , "as-is"                   => \$AS_IS
        , "author=s"                => \$AUTHOR
        , "email=s"                 => \$email

        , "base=s"                  => \$BASE
        , "document=s"              => \$DOC
        , "disclaimer-file=s"       => \$DISCLAIMER_FILE

        , "t|title=s"               => \$TITLE
        , "language=s"              => \$LANG_ISO

        , "button-previous=s"       => \$BUT_PREV
        , "button-next=s"           => \$BUT_NEXT
        , "button-top=s"            => \$BUT_TOP
        , "button-heading-top"      => \$OPT_HEADING_TOP_BUTTON

        , "html-body=s"             => \$HTML_BODY_ATTRIBUTES
        , "html-font=s"             => \$FONT
        , "F|html-frame"            => \$FRAME

        , "script-file=s"           => \$SCRIPT_FILE

        , "css-file=s"              => \@CSS_FILE
        , "css-font-type=s"         => \$CSS_FONT_TYPE
        , "css-font-size=s"         => \$CSS_FONT_SIZE
        , "css-font-normal"         => \$fontNormal
        , "css-font-readable"       => \$fontReadable

        , "css-code-note=s"         => \$codeNote
        , "css-code-3d"             => \$code3d
        , "css-code-bg"             => \$codeBg
        , "css-code-bg2"            => \$codeBg2

        , "delete-lines=s"          => \$DELETE_REGEXP
        , "delete-email-headers"    => \$DELETE_EMAIL
        , "delete-default!"         => \$deleteDefault

        , "name-uniq"               => \$NAME_UNIQ
        , "T|toc-url-print"         => \$PRINT_NAME_REFS
        , "url=s"                   => \$DOC_URL

        , "simple"                  => \$OUTPUT_SIMPLE
        , "quiet"                   => \$QUIET
        , "print"                   => \$PRINT
        , "P|print-url"             => \$PRINT_URL
        , "time"                    => \$time

        , "picture-alt!"            => \$PICTURE_ALT

        , "split=s"                 => \$SPLIT_REGEXP
        , "S1|split1"               => \$SPLIT1
        , "S2|split2"               => \$SPLIT2
        , "SN|split-name-files"     => \$SPLIT_NAME_FILENAMES

        , "t2html-tags!"            => \$OBEY_T2HTML_DIRECTIVES

        , "Out"                     => \$OUTPUT_AUTOMATIC
        , "Out-dir=s"               => \$OUTPUT_DIR

        , "Reference-separator=s@"  => \$referenceSeparator
        , "reference=s@"            => \@reference

        , "link-check"              => \$LINK_CHECK
        , "L|Link-check-single"     => \$LINK_CHECK_ERR_TEXT_ONE_LINE
        , "Link-cache=s"            => \$linkCacheFile

        , "Xhtml"                   => \$XHTML_RENDER

        , "meta-description=s"      => \$META_DESC
        , "meta-keywords=s"         => \$META_KEYWORDS

    );

    $verb = 1   if   defined $verb  and  $verb == 0;
    $verb = 0   if ! defined $verb;

    if ( $debug )
    {
        warn "$id: ARGV => [@ARGV]\n";
        PrintArray( "$id: ARGV after getopt", \@ARGV );

        $verb = 10;
    }
    else
    {
        $debug = 0;
    }

    $help       and  Help();
    $helpHTML   and  Help(undef, -html);
    $helpMan    and  Help(undef, -man);
    $testpage   and  TestPage();

    if ( $version )
    {
        print "$VERSION $PROGNAME $URL $PROGRAM_NAME\n";
        exit 0;
    }

    if ( $XHTML_RENDER )
    {
        my $doctype = Here <<"EOF";
        <!DOCTYPE HTML PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
         "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transiotional.dtd">
EOF

        #  xml:lang="" lang=""

        my $begin = qq(<html xmlns="http://www.w3.org/1999/xhtml">);

        $HTML_HASH{doctype} = $doctype;
        @HTML_HASH{qw(br hr pend)} = ("<br />", "<hr />", "</p>");
    }

    if ( defined $OPT_HEADING_TOP_BUTTON )
    {
        $OPT_HEADING_TOP_BUTTON = 1;
    }

    if ( defined $code3d )
    {
        $CSS_CODE_STYLE = -d3;
        $CSS_CODE_STYLE_ATTRIBUTES = $code3d  if $code3d =~ /[a-z]/i
    }
    elsif ( defined $codeBg )
    {
        $CSS_CODE_STYLE = -shade;
        $CSS_CODE_STYLE_ATTRIBUTES = $codeBg  if $codeBg =~ /[a-z]/i
    }
    elsif ( defined $codeBg2 )
    {
        $CSS_CODE_STYLE = -shade2;
        $CSS_CODE_STYLE_ATTRIBUTES = $codeBg2  if $codeBg2 =~ /[a-z]/i
    }

    unless ( $CSS_CODE_STYLE )
    {
        $CSS_CODE_STYLE = -notset;
    }

    if ( defined $codeNote )
    {
        if ( $CSS_CODE_STYLE eq -notset )
        {
            die "$id: Which css style you want with --css-code-note? "
                . "Please select one of -css-code-* options.";
        }

        $ARG = $codeNote;

        unless ( /\S/ )
        {
            die "$id: You must supply search regexp: --css-code-note='REGEXP'";
        }

        if ( s/\(([^?])/(?:$1/g  )
        {
            $verb and warn "$id: Incorrect --css-code-note."
                , " Must use non-grouping parens in regexp."
                , " Fixed to format: $ARG ";
        }

        $CSS_CODE_STYLE_NOTE = $ARG;
    }
    else
    {
        $CSS_CODE_STYLE_NOTE = 'Note:';
    }

    unless ( defined $OBEY_T2HTML_DIRECTIVES )
    {
        $OBEY_T2HTML_DIRECTIVES = 1;
    }

    $LINK_CHECK = 1  if    $LINK_CHECK_ERR_TEXT_ONE_LINE;

    if ( $linkCacheFile )
    {
        LinkCache( -action => '-read', -arg => $linkCacheFile);
    }

    for ( @reference )
    {
        my $sep = $referenceSeparator || "=";
        my ( $key, $value ) = split /$sep/, $ARG;       #font-lock s/

        unless ( $key and $value )
        {
            die "No separator [$sep] found from --reference [$ARG]";
        }

        $REFERENCE_HASH{ $key } = $value;

        $debug  and warn "$id: [$ARG] Making reference [$key] => [$value]\n";
    }

    if ( $LANG_ISO !~ /^[a-z][a-z]/ )                               #font s/
    {
        die "$id: --language setting must contain two character ISO 639 code."
    }
    else
    {
        my $lang = substr lc $LANG_ISO, 0, 2;

        if ( exists $LANGUAGE_HASH{-toc }{$lang} )
        {
            $LANG_ISO = $lang;
        }
        else
        {
            warn "$id: Language [$LANG_ISO] is not supported, please contact "
                , "maintainer. Switched to English."
                ;
            $LANG_ISO = "en";
        }
    }

    if ( defined $email )
    {
        $OPT_EMAIL = $email;
    }
    else
    {
        $OPT_EMAIL = '';
    }

    if ( defined $DOC_URL )
    {
        local $ARG = $DOC_URL;
        m,/$,  and  die  "$id: trailing slash in --url ? [$DOC_URL]"; #font m"
    }

    if ( defined $OUTPUT_DIR  and $OUTPUT_DIR eq "none" )           #font m"
    {
        undef $OUTPUT_DIR;
    }

    $OUTPUT_DIR  and  $OUTPUT_AUTOMATIC = 1;

    if ( $FRAME and $XHTML_RENDER )
    {
        die "$id: Conflicting options --html-frame and --Xhtml. Use only one.";
    }

    if ( $FRAME )
    {
        $OUTPUT_AUTOMATIC = 1;
    }

    if ( not defined $deleteDefault  or  $deleteDefault == 1 )
    {
        #   Delete Emacs folding.el marks that keeps text in sections. #fl
        #
        #       # {{{  Folding begin mark
        #       # }}}  Folding end mark
        #
        #   Delete also comments
        #
        #       #_COMMENT

        $DELETE_REGEXP = '^(?:#\s*)?([{]{3}|[}]{3}|(#_comment(?i)))'
    }

    if ( $BASE ne '' )
    {

        $BASE_URL_ALL   = $BASE;        # copy original
        local $ARG      = $BASE;

        s,\n,,g;                        # No newlines

        #   If /users/foo/ given, treat as file access protocol

        m,^/,     and    $ARG = "file:$ARG";   #font s,

        #   To ensure that we really get filename

        not m,/,   and   die "Base must contain slash, URI [$ARG]"; #font m"

        warn "Base may need trailing slash: $ARG" if /file/ and not m,/$,;

        #   Exclude the filename part

        $BASE_URL = $ARG;
        $BASE_URL = $1 if m,(.*)/,;
    }

    if ( defined @CSS_FILE  and  @CSS_FILE )
    {
        $JAVA_CODE = '';

        for my $file (@CSS_FILE)
        {
            $JAVA_CODE .= qq(<link rel="stylesheet")
                        . qq( type="text/css" href="$file">\n);
        }
    }

    if ( defined $SCRIPT_FILE  and  $SCRIPT_FILE ne '' )
    {
        local *FILE;

        $debug  and
            print "$id: Reading CSS and Java definitions form $SCRIPT_FILE\n";

        if ( open FILE, "< $SCRIPT_FILE" )
        {
            $JAVA_CODE = join '', <FILE>;
            close FILE;
        }
        else
        {
            warn "$id: Couldn't read [$SCRIPT_FILE] $ERRNO";
            $JAVA_CODE = "<!-- ERROR: couldn't import -->";
        }
    }

    if ( $LINK_CHECK )
    {
        $LINK_CHECK                  = 1;
        $MODULE_LWP_OK               = CheckModule( 'LWP::UserAgent');
        #  http://search.cpan.org/author/PODMASTER/HTML-LinkExtractor-0.07/LinkExtractor.pm
        $MODULE_LINKEXTRACTOR_OK     = CheckModule( 'HTML::LinkExtractor');

        if ( not $MODULE_LWP_OK )
        {
            die "Need library LWP::UserAgent to check links.";
        }
    }

    $OUTPUT_TYPE  = $OUTPUT_TYPE_UNDEFINED;
    $OUTPUT_TYPE  = $OUTPUT_TYPE_SIMPLE   if $OUTPUT_SIMPLE;
    $OUTPUT_TYPE  = $OUTPUT_TYPE_QUIET    if $QUIET;

    if ( defined $OPT_AUTO_DETECT )
    {
        if (  $OPT_AUTO_DETECT =~ /^$|^\d+$/ )
        {
            # Default value
            $OPT_AUTO_DETECT = "(?i)#T2HTML-";
        }
    }

    if ( defined $SPLIT1 )
    {
        $SPLIT_REGEXP = '^([.0-9]+ )?[A-Z][a-z0-9]';
        $debug and warn "$id: SPLIT_REGEXP = $SPLIT_REGEXP\n";
    }

    if ( defined $SPLIT2 )
    {
        $SPLIT_REGEXP = '^    ([.0-9]+ )?[A-Z][a-z0-9]';
        $debug and warn "$id: SPLIT_REGEXP = $SPLIT_REGEXP\n";
    }

    use vars qw( $HOME_ABS_PATH );

    if ( defined $PRINT_URL )
    {
        #   We can't print absolute references like:
        #   file:/usr136/users/PM3/foo/file.html because that cannot
        #   be swallowed by browser. We must canonilise it to $HOME
        #   format file:/users/foo/file.html
        #
        #   Find out where is HOME

        my $previous = cwd();

        if ( defined $HOME  and  $HOME ne '' )
        {
            chdir $HOME;
            $HOME_ABS_PATH = cwd();
            chdir $previous;
        }
    }

    if ( $AS_IS )
    {
        $BUT_TOP = $BUT_PREV = $BUT_NEXT = "";
    }

    # .................................................... css fonts ...

    unless ( defined $CSS_FONT_SIZE )
    {
        # $CSS_FONT_SIZE  = $CSS_BODY_FONT_SIZE_NORMAL;
    }

    unless ( defined $CSS_FONT_TYPE )
    {
        $CSS_FONT_TYPE  = $CSS_BODY_FONT_TYPE_NORMAL;
    }

    if ( $fontNormal )
    {
        $CSS_FONT_TYPE = $CSS_BODY_FONT_TYPE_NORMAL;
    }
    elsif ( $fontReadable )
    {
        $CSS_FONT_TYPE = $CSS_BODY_FONT_TYPE_READABLE
    }

    if ( $AS_IS  and  $FRAME )
    {
        warn "$id: [WARNING] --as-is cancels option --html-frame."
            . " Did you mean --quiet?";

    }

    $debug  and  PrintArray("$id: end [debug=$debug]", \@ARGV);
}

# }}}
# {{{ usage/help

# ***************************************************************** help ****
#
#   DESCRIPTION
#
#       Print help and exit.
#
#   INPUT PARAMETERS
#
#       $msg    [optional] Reason why function was called.
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

=pod

=head1 NAME

t2html - Simple text to HTML converter. Relies on text indentation rules.

=head1 README

Convert pure text files into nice looking, possibly framed, HTML pages.

B<Requirements for the input ascii files>

The file must be written in Technical Format, whose layout is described in
the this manual. Basicly the idea is simple and there are only two heading
levels: one at column 0 and the other at column 4 (halfway between the tab
width). Standard text starts at column 8 (the position after pressed tab-key).

The idea of technical format is that each column represents different
rendering layout in the generated HTML. There is no special markup needed
in the text file, so you can use the text version as a master copy of a FAQ
etc. Bullets, numbered lists, word emphasis and quotation etc. can
expressed in natural way.

B<HTML description>

The generated HTML includes embedded Cascading Style Sheet 2 (CSS2) and a
small piece of Java code. The CSS2 is used to colorize the page loyout and
to define suitable printing font sizes. The generated HTML also takes an
approach to support XHTML. See page http://www.w3.org/TR/xhtml1/#guidelines
where the backward compatibility recommendations are outlined:

    Legal HTML          XHTML requires
    <P>                 <p> ..</p>
    <BR>                <br></br>
    <HR>                <hr></hr>

XHTML does not support fragment identifiers #foo, with the C<name> element,
but uses C<id> instead. For backward compatibility both elements are
defined:

    < ..name="tag">     Is now <.. name="tag" id="tag">

NOTE: This program was never designed to be used for XHTML and the
strict XHTML validity is not to be expected.

B<Motivation>

The easiest format to write large documents, like FAQs, is text. A text
file offers WysiWyg editing and it can be turned easily into HTML format.
Text files are easily maintained and there is no requirements for special
text editors. Any text editor like notepad, vi, Emacs can be used to
maintain the documents.

Text files are also the only sensible format if documents are kept under
version control like RCS, CVS, SVN, Arch, Perforce, ClearCase. They can be
asily compared with diff and patches can be easily received and sent to
them.

To help maintining large documents, there is also available an
I<Emacs> minor mode, package called I<tinytf.el>, which offers text
fontification with colors, Indentation control, bullet filling,
heading renumbering, word markup, syntax highlighting etc.
See project http://freshmeat.net/projects/emacs-tiny-tools

=head1 SYNOPSIS

To convert text file into HTML:

    t2html [options] file.txt > file.html

In addition to making HTML pages, program includes feature to check broken
links and report them in I<egrep -n> like fashion:

    t2html --Link-check-single --quiet file.txt

To check links from multiple pages and cache good links to separate file,
use B<--Link-cache> option. The next link check will run much faster
because cached valid links will not be fetched again. At regular intervals
delete the link cache file to force complete check.

    t2html --Link-check-single --Link-cache ~/tmp/link.cache \
              --quiet file.txt

In case there are need for slides, is is possible to plit big document into
pieces according to toplevel headings:

    t2html --S1 --SN | t2html --simple -Out

=head1 OPTIONS

=head2 Html: Header and Footer options

=over 4

=item B<--as-is>

Any extra HTML formatting or text manipulation is suppressed. Text is
preserved as it appears in file. Use this option if you plan to deliver or
and print the text as seen.

    o  If file contains "Table of Contents" it is not removed
    o  Table of Content block is not created (it usually would)

=item B<--author -a STR>

Author of document e.g. B<--author "John Doe">

=item B<--disclaimer-file> FILE

The text that appears at the footer is read from this file. If not given
the default copyright text is added. Options C<--quiet> and
C<--simple> suppress disclaimers.

=item B<--document FILE>

B<Name> of the document or filename. You could list all
alternative URLs to the document with this option.

=item B<--email -e EMAIL>

The contact address of the author of the document. Must be pure email
address with no "<" and ">" characters included. Eg.
B<--email foo@example.com>

    --email "<me@here.com>"     WRONG
    --email "me@here.com"       right

=item B<--simple> B<-s>

Print minimum footer only: contact, email and date. Use C<--quiet> to
completely discard footer.

=item B<--t2html-tags>

Allow processing embedded #T2HTML-<tag> directives inside file. See full
explanation by reading topic C<EMBEDDED DIRECTIVES INSIDE TEXT>. By
default, you do not need to to supply this option - it is "on" by default.

To disregard embedded directives in text file, supply "no" option:
B<--not2html-tags>.

=item B<--title STR> B<-t STR>

The title text that appears in top frame of browser.

=item B<--url URL>

=back

Location of the HTML file. When B<--document> gave the name, this gives the
location. This information is printed at the Footer.

=head2 Html: Navigation urls

=over 4

=item B<--base URL>

URL location of the HTML file in the B<destination site> where it will be
put available. This option is needed only if the document is hosted on a
FTP server (rare, but possible). A FTP server based document cannot use
Table Of Contents links (fragment I<#tag> identifiers) unless HTML tag BASE
is also defined.

The argument can be full URL to the document:

    --base ftp://ftp.example.com/file.html
    --base ftp://ftp.example.com/

=item B<--button-heading-top>

Add additional B<[toc]> navigation button to the end of each heading. This
may be useful in long non-framed HTML files.

=item B<--button-top URL>

Buttons are placed at the top of document in order: [previous][top][next]
and I<--button-*> options define the URLs.

If URL is string I<none> then no button is inserted. This may be handy if
the buttons are defined by a separate program. And example using Perl:

    #!/usr/bin/perl

    my $top   = "index.html";             # set defaults
    my $prev  = "none";
    my $next  = "none";

    # ... somewhere $prev or $next may get set, or then not

    qx(t2html --button-top "$top" --button-prev "$prev" --button-next "$next" ...);

    # End of sample program

=item B<--button-prev URL>

URL to go to previous document or string I<none>.

=item B<--button-next URL>

URL to go to next document or string I<none>.

=item B<--reference tag=value>

You can add any custom references (tags) inside text and get them expand to
any value. This option can be given multiple times and every occurrance
of TAG is replaced with VALUE. E.g. when given following options:

    --reference "#HOME-URL=http://www.example.com/dir"
    --reference "#ARCHIVE-URL=http://www.example.com/dir/dir2"

When referenced in text, the generated HTML includes expanded expanded to
values. An example text:

        The homepage is #HOME-URL/page.html and the mirrot page it at
        #ARCHIVE-URL/page.html where you can find the latest version.

=item B<--reference-separator STRING>

See above. String that is used to split the TAG and VALUE. Default is equal
sign "=".

=item B<--Toc-url-print -T>

Display URLs (contructed from headings) that build up the Table of Contents
(NAME AHREF tags) in a document. The list is outputted to stderr, so that
it can be separated:

    % t2html --Toc-url-print tmp.txt > file.html 2> toc-list.txt

Where would you need this? If you want to know the fragment identifies
for your file, you need the list of names.

  http://www.example.com/myfile.html#fragment-identifier

=back

=head2 Html: Controlling CSS generation (HTML tables)

=over 4

=item B<--css-code-bg>

This option affects how the code section (column 12) is rendered. Normally
the section is surrounded with a <pre>..</pre> codes, but with this
options, something more fancier is used. The code is wrapped inside a
<table>...</table> and the background color is set to a shade of gray.

=item B<--css-code-note "REGEXP" >

Option B<--css-code-bg> is required to activate this option. A special word
defined using regexp (defualt is 'Note:') will mark code sections specially.
The C<first word> is matched against the supplied Perl regexp.

The supplied regexp must not, repeat, must not, include any matching group
operators. This simply means, that grouping parenthesis like
C<(one|two|three)> are not allowed. You must use the Perl non-grouping ones
like C<(?:one|two|three)>. Please refer to perl manual page [perlre] if
this short introduction did not give enough rope.

With this options, instead of rendering column 12 text with <pre>..</pre>,
the text appears just like regular text, but with a twist. The background
color of the text has been changed to darker grey to visually stand out
form the text.

An example will clarify. Suppose that you passed options B<--css-code-bg>
and B<--css-code-note='(?:Notice|Note):'>, which instructed to treat the
first paragraphs at column 12 differently. Like this:

    This is the regular text that appears somewhere at column 8.
    It may contain several lines of text in this paragraph.

        Notice: Here is the special section, at column 12,
        and the first word in this paragraph is 'Notice:'.
        Only that makes this paragraph at column 12 special.

    Now, we have some code to show to the user:

        for ( i = 0; i++; i < 10 )
        {
            //  Doing something in this loop
        }

One note, text written with initial special word, like C<Notice:>,
must all fit in one full pragraph. Any other paragraphs that follow,
are rendered as code sections. Like here:

    This is the regular text that appears somewhere
    It may contain several lines of text in this paragraph

        Notice: Here is the special section, at column 12,
        and the first word in this paragraph is 'Notice:'
        which makes it special

        Hoewver, this paragraph IS NOT rendered specially
        any more. Only the first paragraph above.

        for ( i = 0; i++; i < 10 )
        {
            //  Doing something in this loop
        }

As if this were not enough, there are some special table control
directives that let you control the <table>..</table> which is
put around the code section at column 12. Here are few examples:

    Here is example 1

        #t2html::td:bgcolor=#F7F7DE

        for ( i = 0; i++; i < 10 )
        {
            //  Doing something in this loop
        }

    Here is example 2

        #t2html::td:bgcolor=#F7F7DE:tableborder:1

        for ( i = 0; i++; i < 10 )
        {
            //  Doing something in this loop
        }

    Here is example 3

        #t2html::td:bgcolor="#FFFFFF":tableclass:dashed

        for ( i = 0; i++; i < 10 )
        {
            //  Doing something in this loop
        }

    Here is example 4

        #t2html::td:bgcolor="#FFFFFF":table:border=1_width=94%_border=0_cellpadding="10"_cellspacing="0"

        for ( i = 0; i++; i < 10 )
        {
            //  Doing something in this loop
        }

Looks cryptic? Cannot help that and in order for you to completely
understand what these directives do, you need to undertand what elements
can be added to the <table> and <td> tokens. Refer to HTML specification
for available attributes. Here is briefing what you can do:

The start command is:

    #t2html::
            |
            After this comes attribute pairs in form key:value
            and multiple ones as key1:value1:key2:value2 ...

The C<key:value> pairs can be:

    td:ATTRIBUTES
       |
       This is converted into <td attributes>

    table:ATTRIBUTES
          |
          This is converted into <table attributes>

There can be no spaces in the ATTRIBUTES, because the C<First-word> must
be one contiguous word. An underscore can be used in place of space:

    table:border=1_width=94%
          |
          Interpreted as <table border="1" width="94%">

It is also possible to change the default CLASS style with word
C<tableclass>. In order the CLASS to be useful, its CSS definitions must be
either in the default configuration or supplied from a external file.
See option B<--script-file>.

    tableclass:name
               |
               Interpreted as <table class="name">

For example, there are couple of default styles that can be used:

    1) Here is CLASS "dashed" example

        #t2html::tableclass:dashed

            for ( i = 0; i++; i < 10 )
            {
                //  Doing something in this loop
            }

    2) Here is CLASS "solid" example:

        #t2html::tableclass:solid

            for ( i = 0; i++; i < 10 )
            {
                //  Doing something in this loop
            }

You can change any individual value of the default table
definition which is:

    <table  class="shade-note">

To change e.g. only value cellpadding, you would say:

     #t2html::table:tablecellpadding:2

If you are unsure what all of these were about, simply run program with
B<--test-page> and look at the source and generated HTML files. That
should offer more rope to experiment with.

=item B<--css-file FILE>

Include <LINK ...> which refers to external CSS style definition source.
This option is ignored if B<--script-file> option has been given,
because that option imports whole content inside HEAD tag. This option
can appear multiple times and the external CSS files are added in
listed order.

=item B<--css-font-type CSS-DEFINITION>

Set the BODY element's font defintion to CSS-DEFINITION. The
default value used is the regular typeset used in newspapers and books:

    --css-font-type='font-family: "Times New Roman", serif;'

=item B<--css-font-size CSS-DEFINITION>

Set the body element's font size to CSS-DEFINITION. The default font
size is expressed in points:

    --css-font-size="font-size: 12pt;"

=back

=head2 Html: Controlling the body of document

=over 4

=item B<--delete REGEXP>

Delete lines matching perl REGEXP. This is useful if you use some document
tool that uses navigation tags in the text file that you do not want to show
up in generated HTML.

=item B<--delete-email-headers>

Delete email headers at the beginning of file, until first empty line that
starts the body. If you keep your document ready for Usenet news posting, they
may contain headers and body:

    From: ...
    Newsgroups: ...
    X-Sender-Info:
    Summary:

    BODY-OF-TEXT

=item B<--nodelete-default>

Use this option to suppress default text deletion (which is on).

Emacs C<folding.el> package and vi can be used with any text or
programming language to place sections of text between tags B<{{{> and
B<}}}>. You can open or close such folds. This allows keeping big
documents in order and manageable quite easily. For Emacs support,
see. ftp://ftp.csd.uu.se/pub/users/andersl/beta/

The default value deletes these markers and special comments
C<#_comment> which make it possible to cinlude your own notes which
are not included in the generated output.

  {{{ Security section

  #_comment Make sure you revise this section to
  #_comment the next release

  The seecurity is an important issue in everyday administration...
  More text ...

  }}}

=item B<--html-body STR>

Additional attributes to add to HTML tag <BODY>. You could e.g. define
language of the text with B<--html-body LANG=en> which would generate
HTML tag <BODY LANG="en"> See section "SEE ALSO" for ISO 639.

=item B<--html-column-beg="SPEC HTML-SPEC">

The default interpretation of columns 1,2,3  5,6,7,8,9,10,11,12 can be
changed with I<beg> and I<end> swithes. Columns 0,4 can't be changed because
they are reserved for headings. Here are some samples:

    --html-column-beg="7quote <em class='quote7'>"
    --html-column-end="7quote </em>"

    --html-column-beg="10    <pre> class='column10'"
    --html-column-end="10    </pre>"

    --html-column-beg="quote <span class='word'>"
    --html-column-end="quote </span>"

B<Note:> You can only give specifications up till column 12. If text
is beyound column 12, it is interpreted like it were at column 12.

In addition to column number, the I<SPEC> can also be one of the
following strings

    Spec    equivalent word markup
    ------------------------------
    quote   `'
    bold    _
    emp     *
    small   +
    big     =
    ref     []   like: [Michael] referred to [rfc822]

    Other available Specs
    ------------------------------
    7quote      When column 7 starts with double quote.

For style sheet values for each color, refer to I<class> attribute and use
B<--script-file> option to import definitions. Usually /usr/lib/X11/rgb.txt
lists possible color values and the HTML standard at http://www.w3.org/
defines following standard named colors:

    Black       #000000  Maroon  #800000
    Green       #008000  Navy    #000080
    Silver      #C0C0C0  Red     #FF0000
    Lime        #00FF00  Blue    #0000FF
    Gray        #808080  Purple  #800080
    Olive       #808000  Teal    #008080
    White       #FFFFFF  Fuchsia #FF00FF
    Yellow      #FFFF00  Aqua    #00FFFF

=item B<--html-column-end="COL HTML-SPEC">

See B<--html-column-beg>

=item B<--html-font SIZE>

Define FONT SIZE. It might be useful to set bigger font size for presentations.

=item B<--html-frame -F [FRAME-PARAMS]>

If given, then three separate HTML files are generated. The left frame will
contain TOC and right frame contains rest of the text. The I<FRAME-PARAMS>
can be any valid parameters for HTML tag FRAMESET. The default is
C<cols="25%,75%">.

Using this implies B<--Out> option automatically, because three files
cannot be printed to stdout.

    file.html

    --> file.html       The Frame file, point browser here
        file-toc.html   Left frame (navigation)
        file-body.html  Right frame (content)

=item B<--language ID>

Use language ID, a two character ISO identifier like "en" for English
during the generation of HTML. This only affects the text that is shown to
end-user, like text "Table Of contents". The default setting is "en". See
section "SEE ALSO" for standards ISO 639 and ISO 3166 for proper codes.

The selected langauge changes propgram's internal arrays in two ways: 1)
Instead of default "Table of ocntents" heading the national langaugage
equivalent will be used 2) The text "Pic" below embedded sequentially
numbered pictures will use natinal equivalent.

If your languagae is not supported, please send the phrase for "Table of
contents" and word "Pic" in your langauge to the maintainer.

=item B<--script-file FILE>

Include java code that must be complete <script...></script> from FILE. The
code is put inside <head> of each HTML.

The B<--script-file> is a general way to import anything into the HEAD
element. Eg. If you want to keep separate style definitions for
all, you could only import a pointer to a style sheet.
See I<14.3.2 Specifying external style sheets> in HTML 4.0 standard.

=item B<--meta-keywords STR>

Meta keywords. Used by search engines. Separate kwywords like "AA, BB, CC"
with commas. Refer to HTML 4.01 specification and topic "7.4.4 Meta data"
and see http://www.htmlhelp.com/reference/wilbur/ and

    --meta-keywords "AA,BB,CC"

=item B<--meta-description STR>

Meta description. Include description string, max 1000 characters. This is
used by search engines. Refer to HTML 4.01 specification and topic
"7.4.4 Meta data"

=item B<--name-uniq>

First 1-4 words from the heading are used for the HTML I<name> tags.
However, it is possible that two same headings start with exactly the same
1-4 words. In those cases you have to turn on this option. It will use
counter 00 - 999 instead of words from headings to construct HTML I<name>
references.

Please use this option only in emergencies, because referring to jump block
I<name> via

    httpI://example.com/doc.html#header_name

is more convenient than using obscure reference

    httpI://example.com/doc.html#11

In addition, each time you add a new heading the number changes, whereas
the symbolic name picked from heading stays as long as you do not change
the heading. Think about welfare of your netizens who bookmark you pages.
Try to make headings to not have same subjects and you do not need this
option.

=back

=head2 Document maintenance and batch job commands

=over 4

=item B<--Auto-detect>

Convert file only if tag C<#T2HTML-> is found from file. This option
is handy if you run a batch command to convert all files to HTML, but
only if they look like HTML base files:

    find . -name "*.txt" -type f \
         -exec t2html --Auto-detect --verbose --Out {} \;

The command searches all *.txt files under current directory and feeds
them to conversion program. The B<--Auto-detect> only converts files
which include C<#T2HTML-> directives. Other text files are not
converted.

=item B<--link-check -l>

Check all http and ftp links.
I<This option is supposed to be run standalone>
Option B<--quiet> has special meaning when used with link check.

With this option you can regularly validate your document and remove dead
links or update moved links. Problematic links are outputted to I<stderr>.
This link check feature is available only if you have the LWP web
library installed. Program will check if you have it at runtime.

Links that are big, e.g. which match I<tar.gz .zip ...> or that run
programs (links with ? character) are ignored because the GET request
used in checking would return whole content of the link and it would.
be too expensive.

A suggestion: When you put binary links to your documents, add them with
space:

    http://example.com/dir/dir/ filename.tar.gz

Then the program I<does> check the http addresses. Users may not be
able to get the file at one click, checker can validate at least the
directory. If you are not the owner of the link, it is also possible
that the file has moved of new version name has appeared.

=item B<--Link-check-single -L>

Print condensed output in I<grep -n> like manner I<FILE:LINE:MESSAGE>

This option concatenates the url response text to single line, so that you
can view the messages in one line. You can use programming tools (like
Emacs M-x compile) that can parse standard grep syntax to jump to locations
in your document to correct the links later.

=item B<--Out -O>

write generated HTML to file that is derived from the input filename.

    --Out --print /dir/file            --> /dir/file.html
    --Out --print /dir/file.txt        --> /dir/file.html
    --Out --print /dir/file.this.txt   --> /dir/file.this.html

=item B<--Link-cache CACHE_FILE>

When links are checked periodically, it would be quite a rigorous to
check every link every time that has already succeeded. In order to
save link checking time, the "ok" links can be cached into separate
file. Next time you check the links, the cache is opened and only
links found that were not in the cache are checked. This should
dramatically improve long searches. Consider this example, where
every text file is checked recursively.

    $ t2html --Link-check-single \
      --quiet --Link-cache ~tmp/link.cache \
      `find . -name "*.txt" -type f`

=item B<--Out-dir DIR>

Like B<--Out>, but chop the directory part and write output files to
DIR. The following would generate the HTML file to current directory:

    --Out-dir .

If you have automated tool that fills in the directory, you can use word
B<none> to ignore this option. The following is a no-op, it will not generate
output to directory "none":

    --Out-dir none

=item B<--print -p>

Print filename to stdout after HTML processing. Normally program prints
no file names, only the generated HTML.

    % t2html --Out --print page.txt

    --> page.html

=item B<--print-url -P>

Print filename in URL format. This is useful if you want to check the
layout immediately with your browser.

    % t2html --Out --print-url page.txt | xargs lynx

    --> file: /users/foo/txt/page.html

=item B<--split REGEXP>

Split document into smaller pieces when REGEXP matches. I<Split commands
are standalone>, meaning, that it starts and quits. No HTML conversion for
the file is engaged.

If REGEXP is found from the line, it is a start point of a split. E.g. to
split according to toplevel headings, which have no numbering, you would
use:

    --split '^[A-Z]'

A sequential numbers, 3 digits, are added to the generated partials:

    filename.txt-NNN

The split feature is handy if you want to generate slides from each heading:
First split the document, then convert each part to HTML and finally print
each part (page) separately to printer.

=item B<--split1 --S1>

This is shorthand of B<--split> command. Define regexp to split on toplevel
heading.

=item B<--split2 --S2>

This is shorthand of B<--split> command. Define regexp to split on second
level heading.

=item B<--split-named-files --SN>

Additional directive for split commands. If you split e.g. by headings using
B<--split1>, it would be more informative to generate filenames according
to first few words from the heading name. Suppose the heading names where
split occur were:

    Program guidelines
    Conclusion

Then the generated partial filenames would be as follows.

    FILENAME-program_guidelines
    FILENAME-conclusion

=item B<--Xhtml>

Render using strict XHTML. This means using <hr/>, <br/> and paragraphs
use <p>..</p>.

C<Note: this option is experimental. See BUGS>

=back

=head2 Miscellaneous options

=over 4

=item B<--debug LEVEL>

Turn on debug with positive LEVEL number. Zero means no debug.

=item B<--help -h>

Print help screen.

=item B<--Help-html>

Print help in HTML format.

=item B<--Help-man>

Print help page in Unix manual page format. You want to feed this output to
B<nroff -man> in order to read it.

=item B<--test-page>

Print the test page: HTML and example text file that demonstrates
the capabilities.

=item B<--time>

Print to stderr time spent used for handling the file.

=item B<--verbose [LEVEL]>

Print verbose messages.

=item B<--quiet -q>

Print no footer at all. This option has different meaning if
I<--link-check> option is turned on: print only errorneous links.

=item B<--Version -V>

Print program version information.

=back

=head1 DESCRIPTION

This is simple text to HTML converter. Unlike other tools, this
tries to minimize the use of text tags to format the document,
The basic idea is to rely on indentation level, and the layout used is
called 'Technical format' (TF)

    --//-- decription start

    0123456789 123456789 123456789 123456789 123456789 column numbers

    Heading 1 starts from left with big letter

     The column positions are currently undeined and may not
     format correcly. Do ot place text at columns 1,2,3

        This is heading2 at column 4 started with big letter

            Standard text starts at column 8, you can *emphatize*
            text or make it _strong_ and write =SmallText= or
            +BigText+ show variable name `ThisIsAlsoVariable'.
            You can `_*nest*_' `the' markup. more txt in this
            paragraph txt txt txt txt txt txt txt txt txt txt txt
            txt txt txt txt txt txt txt txt txt txt txt txt txt
            txt txt txt txt txt txt txt txt txt txt txt txt txt
            txt

          Normal but colored text is between columns 5, 6

           Emphatised text at column 7, like heading level 3

           "Special <em> text at column 7 starts with double quote"

            Another standard text block at column 8 txt txt txt
            txt txt txt txt txt txt txt txt txt txt txt txt txt
            txt txt txt txt txt txt txt txt txt txt txt txt txt
            txt txt txt txt txt txt txt

             strong text at columns 9 and 11

              Column 10 is normally reserved for quotations
              Column 10 is normally reserved for quotations
              Column 10 is normally reserved for quotations
              Column 10 is normally reserved for quotations

                Column 12 and further is reserved for code examples
                Column 12 and further is reserved for code examples
                All text here are surrounded by <pre> HTML codes
                (This CODE column in affected by --css-code* options,
                see more ideas from there.)

        Heading2 at column 4 again

           If you want something like Heading level 3, use colum 7 (bold)

            txt txt txt txt txt txt txt txt txt txt txt txt
            txt txt txt txt txt txt txt txt txt txt txt txt
            txt txt txt txt txt txt txt txt txt txt txt txt

             [1998-09-10 comp.lang.perl.misc Mr. Foo said]

              cited text cited text cited text cited text cited
              text cited text cited text cited text cited text
              cited text cited text cited text cited text cited
              text cited text

             [1998-09-10 comp.lang.perl.misc Mr. Bar said]

              cited text cited text cited text cited text cited
              text cited text cited text cited text cited text
              cited text cited text cited text cited text cited
              text cited text

           If you want something like Heading level 3, use colum 7 (bold)

            txt txt txt txt txt txt txt txt txt txt txt txt
            txt txt txt txt txt txt txt txt txt txt txt txt
            txt txt txt txt txt txt txt txt txt txt txt txt

            *   Bullet 1 text starts at column 1
                txt txt txt txt txt txt txt txt
                ,txt txt txt txt txt txt txt txt

                Notice that previous paragraph ends to P-comma
                code, it tells this paragraph to continue in
                bullet mode, otherwise this text at column 12
                would be intepreted as code section surrpoundedn
                by <pre> HTML codes.

            *   Bullet 2, text starts at column 12
            *   Bullet 3. Bullets are adviced to keep together
            *   Bullet 4. Bullets are adviced to keep together

            .   This is ordered list nbr 1, text starts at column 12
            .   This is ordered list nbr 2
            .   This is ordered list nbr 3

            .This line has BR, notice the DOT-code at beginning
             of line. It is efective only at columns 1..11,
             because column 12 is reserved for code examples.

            .This line has BR code and is displayed in line by itself.
            .This line has BR code and is displayed in line by itself.

            !! This adds an <hr> HTML code, text in line is marked with
            !! <strong> <em>

           "This is emphasised text starting at column 7"
            .And this text is put after the previous line with BR code
           "This starts as separate line just below previous one"
            .And continues again as usual with BR code

            See the document #URL-BASE/document.txt, where #URL-BASE
            tag is substituted with contents of --base switch.

            Make this email address clickable <account@example.com>

            Do not make this email address clickable bar@example.com,
            because it is only an example and not a real address. Notice
            that the last one was not surrounded by <>. Common login names
            like foo, bar, quux are also ignored automatically.

            Also do not make < this@example.com> because there is extra
            white spaces. This may be more convenient way to disable
            email addresses temporarily.

    Heading1 again at colum 0

        Subheading at colum 4

            And regular text, column 8 txt txt txt txt txt txt txt txt txt
            txt txt txt txt txt txt txt txt txt txt txt txt txt txt txt txt
            txt txt txt txt txt txt txt txt txt txt txt

    --//-- decription end

That is it, there is the whole layout described. More formally the rules
of text formatting are secribed below.

=head2 USED HEADINGS

=over 4

=item *

There are only I<two> heading levels in this style. Heading columns are 0
and 4 and the heading must start with big letter or number

=item *

at column 4, if the text starts with small letter, that line is interpreted
as <strong>

=item *

A HTML <hr> mark is added just before printing heading at level 1.

=item *

The headings are gathered, the TOC is built and inserted to the beginning
of HTML page. The HTML <name> references used in TOC are the first 4
sequential words from the headings. Make sure your headings are uniquely
named, otherwise there will be same NAME references in the generated HTML.
Spaces are converted into underscore when joining the words. If you can not
write unique headings by four words, then you must use B<--name-uniq>
switch

=back

=head1 TEXT PLACEMENT RULES

=head2 General

The basic rules for positioning text in certain columns:

=over 4

=item *

Text at column 0 is undefined if it does not start with big letter or number
to indicate Heading level 1.

=item *

Text between colums 1-3 is marked with <em>

=item *

Column 4 is reserved for heading level 2

=item *

Text between colums 5-7 is marked with <strong>

=item *

Text at column 7 is <em> if the first character is double quote.

=item *

Column 10 is reserved for <em> text. If you want to quote someone
or to add reference text, place the text in this column.

=item *

Text at colums 9,11 are marked with <strong>

=back

Column 8 for text and special codes

=over 4

=item *

Column 8 is reserved for normal text

=item *

At the start of text, at colum 8, there can be DOT-code or COMMA-code.

=back

Column 12 is special

=over 4

=item *

Column 12 is treated specially: block is started with <pre> and lines are
marked as <samp></samp>. When the last text at I<column> 12 is found, the
block is closed with </pre> Note follwing example

    txt txt txt         ;evenly placed block, fine, do it like this
    txt txt

    txt txt txt txt     ;Can not terminate the /pre, because last
    txt txt txt txt     ;column is not at 12
        txt txt txt txt

    txt txt txt txt
    txt txt txt txt
        txt txt txt txt
    ;; Finalizing comment, now the text is evenly placed

=back

=head2 Additional tokens for use at column 8

=over 4

=item *

If there is C<.>(dot) at the beginning of a line and immediately
non-whitespace, then <br> code is added to the end of line.

    .This line has BR code at the end.
    While these two line are joined together
    by your browser, depending on the frame width.

=item *

If there is C<,>(comma) then the <p> code is not inserted if the previous
line is empty. If you use both C<.>(dot) and C<,>(comma), they must be in
order dot-comma. The C<,>(comma) works differently if it is used in bullet

A <p> is always added if there is separation of paragraphs, but when you are
writing a bullet, there is a problem, because a bullet exist only as long
as text is kept together

    *   This is a bullet and it has all text ketp together
        even if there is another line in the bullet.

But to write bullets tat spread multiple paragraphs, you must instruct
that those are to kept together and the text in next paragraph is
not <sample> while it is placed at column 12

    *   This is a bullet and it has all text ketp together
        ,even if there is another line in the bullet.

        This is new paragrah to the previous bullet and this is
        not a text sample. See COMMa-code below.

    *   This is new bullet

        // and this is code sample after bullet
        if ( $flag ) { ..do something.. }

=back

=head2 Special text markings

=over 4

=item italic, bold, code, small, big tokens

    _this_      is intepreted as <strong class='word'>this</strong>
    *this*      is intepreted as <em class='word'>this</em>
    `this'      is intepreted as <sample class='word'>this</sample> `

Exra modifiers that can be mixed with the above. Usually if you want
bigger font, CAPITALIZE THE WORDS.

    =this=      is intepreted as <span class="word-small">this</span>
    +this+      is intepreted as <span class="word-big">this</span>
    word [this] is intepreted as <span class="word-ref">this</span>

=item supercripting

    word[this]  is intepreted as superscript. You can use like
                this[1], multiple[(2)] and almost any[(ab)] and
                imaginable[IV superscritps] as long as the left
                bracket is attached to the word.

=item embedding standard HTML tokens

Stanadard special HTML entities can be added inside text in a normal way,
either using sybolic names or the hash code. Here are exmples

    &times; &lt; &gt; &le; &ge; &ne; &radic; &minus;
    &alpha; &beta; &gamma; &divide;
    &laquo; &raquo; &lsaquo; &rsaquo; - &ndash; &mdash;
    &asymp; &equiv; &sum; &fnof; &infin;
    &deg; &plusmn;
    &trade; &copy; &reg;
    &euro; &pound; &yen;

=item embedding PURE HTML into text

B<this feature is highly experimental>. It is possible to embed
pure HTML inside text in occasions, where e.g. some special
formatting is needed. The isea is simple: you write HTML as usual
but double every < and > characters, like:

    <<p>>

The other rule is that all, let's repeat, ALL PURE HTML must be
kept together. There must be no line breaks between pure HTML
lines. This is C<invalid:>

    <<table>

        <<tr>>one
        <<tr>>two

    <</table>>

The pure HTML must be written without separating newlines:

    <<table>
        <<tr>>one
        <<tr>>two
    <</table>>

This "doubling" affects normal text writing rules as well. If you write
documents, where you describe Unix styled HERE-documents, you MUST NOT put
the tokens next to each other:

        bash$ cat<<EOF              # DON'T! It will confuse parser.
        one
        EOF

You must write the above code example using spaces to prevent "<<" from
interpreting as PURE HTML:

        bash$ cat << EOF            # RIGHT, add spaces
        one
        EOF

=back

=over 4

=item drawing a short separator

A !! (two exclamation marks) at text column (position 8) causes adding
immediate <hr> code. any text after !! in the same line is written with
<strong> <em> and inserted just after <hr> code, therefore the word
formatting commands have no effect in this line.

=back

=head2 Http and email marking control

=over 4

=item *

All http and ftp references as well as <foo@example.com> email
addresses are marked clickable. Email must have surrounding <>
characters to be recognized.

=item *

If url is preceded with hyphen, it will not be clickable. If a string
foo, bar, quux, test, site is found from url, then it is not counted as
clickable.

    <me@here.com>                   clickable
    http://example.com              clickable

    < me@here.com>                  not clickable; contains space
    <5dko56$1@news02.deltanet.com>  Message-Id, not clickable

    -http://example.com             hyphen, not clickable
    http://$EXAMPLE                 variable. not clickable

=back

=head2 Lists and bullets

=over 4

=item *

The bulletin table is contructed if there is "o" or "*" at column 8 and 3
spaces after it, so that text starts at column 12. Bulleted lines are
adviced to be kept together; no spaces between bullet blocks.

=item *

The ordered list is started with ".", a dot, and written like bullet where
text starts at column 12.


=back

=head2 Line breaks

=over 4

=item *

All line breaks are visible in your document, do not use more than one line
break to separate paragraphs.

=item *

Very important is that there is only I<one> line break after headings.

=back

=head1 EMBEDDED DIRECTIVES INSIDE TEXT

=over 4

=item Command line options

You can cancel obeying all embedded directives by supplying option
B<--not2html-tags>.

You can include these lines anywhere in the document and their content
is included in HTML output. Each directive line must fit in one line and
it cannot be broken to separate lines.

    #T2HTML-TITLE            <as passed option --title>
    #T2HTML-EMAIL            <as passed option --email>
    #T2HTML-AUTHOR           <as passed option --author>
    #T2HTML-DOC              <as passed option --doc>
    #T2HTML-METAKEYWORDS     <as passed option --meta-keywords>
    #T2HTML-METADESCRIPTION  <as passed option --meta-description>

You can pass command line options embedded in the file. Like if you
wanted the CODE section (column 12) to be coloured with shade of gray,
you could add:

    #T2HTML-OPTION  --css-code-bg

Or you could request turning on particular options. Notice that each line
is exactly as you have passed the argument in command line. Imagine
surrounding double quoted around lines that are arguments to the
associated options.

    #T2HTML-OPTION  --as-is
    #T2HTML-OPTION  --quiet
    #T2HTML-OPTION  --language
    #T2HTML-OPTION  en
    #T2HTML-OPTION  --css-font-type
    #T2HTML-OPTION  Trebuchet MS
    #T2HTML-OPTION --css-code-bg
    #T2HTML-OPTION --css-code-note
    #T2HTML-OPTION (?:Note|Notice|Warning):

You can also embed your own comments to the text. These are stripped away:

    #T2HTML-COMMENT  You comment here
    #T2HTML-COMMENT  You another comment here

=item Embedding files

#INCLUDE- command

This is used to include the content into current current position. The URL
can be a filename reference, where every $VAR is subtituted from the
environment variables. The tilde(~) expansion is not supported. The
included filename is operating system supported path location.

A prefix C<raw:> disables any normal formatting. The file content is
included as is.

The URL can also be a HTTP reference to a remote location, whose content is
included at the point. In case of remote content or when filename ends to
extension C<.html> or C<.html>, the content is stripped in order to make
the inclusion of the content possible. In picture below, only the lines
within the BODY, marked with !!, are included:

    <html>
      <head>
        ...
      </head>
      <body>
        this text                 !!
        and more of this          !!
      </body>
    </html>

Examples:

    #INCLUDE-$HOME/lib/html/picture1.html
    #INCLUDE-http://www.example.com/code.html
    #INCLUDE-raw:example/code.html

=item Embedding pictures

#PIC command is used to include pictures into the text

    #PIC picture.png#Caption Text#Picture HTML attributes#align#
          (1)        (2)          (3)                     (4)

    1.  The NAME or URL address of the picturere. Like image/this.png

    2.  The Text that appears below picture

    3.  Additional attributes that are attached inside <img> tag.
        For <img width="200" height="200">, the line would
        read:

        #PIC some.png#Caption Text#width=200 length=200##

    4.  The position of image: "left" (default), "center", "right"


Note: The C<Caption Text> will also become the ALT text of the image
which is used in case the browser is not capable of showing pictures.
You can suppress the ALT text with option B<--no-picture-alt>.

=item Fragment identifiers for named tags

#REF command is used for refering to HTML <name> tag inside current
document. The whole command must be placed on one single line and
cannot be broken to multiple lines. An example:

    #REF #how_to_profile;(Note: profiling);
          (1)            (2)

    1.  The NAME HTML tag reference in current document, a single word.
        This can also be a full URL link.
        You can get NAME list by enabling --Toc-url-print option.

    2.  The clickable text is delimited by ; characters.

=item Referring to external documents.

C<#URL> tag can be used to embed URLs inline, so that the full
link is not visible. Only the shown text is used to jump to URL.
This directive cannot be broken to separate lines,

     #URL<FULL-HTTP-LINK> <embedded inline text>
         |               |
         |               whitespace allowed here
         Must be kept together

Like if written:

     See search engine #URL<http://www.google.com> <Google>

=back

=head1 TABLE OF CONTENT HEADING

If there is heading 1, which is named exactly "Table of Contents", then all
text up to next heading are discarded from the generated HTML file. This is
done because program generates its own TOC. It is supposed that you use
some text formatting program to generate the toc for you in .txt file and
you do not maintain it manually. For example Emacs package I<tinytf.el> can
be used.

=head1 TROUBLESHOOTING

=head2 Generated HTML document did not look what I intended

The most common mistake is that there are extra newlines in the
document. Keeep I<one> empty line between headings and text, keep I<one>
empty line between paragraphs, keep I<one> empty line between body
text and bullet. Make it your mantra: I<one> I<one> I<one> ...

Next, you may have put text at wrong column position. Remember that the
regular text is at column 8.

If generated HTML suddendly starts using only one font, eg <pre>, then
you have forgot to close the block. Make it read even, like this:

    Code block
        Code block
        Code block
    ;;  Add empty comment here to "close" the code example at column 12

Headings start with a big letter or number, likein "Heading", not
"heading". Double check the spelling.

=head1 EXAMPLES

To print the test page and show all the possibilities:

    % t2html --test-page

To make simple HTML page without any meta information:

    % t2html --title "Html Page Title" --author "Mr. Foo" \
      --simple --Out --print file.txt

If you have periodic post in email format, use B<--delete-email-headers> to
ignore the header text:

    % t2html --Out --print --delete-email-headers page.txt

To make page fast

    % t2html --html-frame --Out --print page.txt

To convert page from a text document, including meta tags, buttons, colors
and frames. Pay attention to switch I<--html-body> which defines document
language.

    % t2html                                         \
    --print                                             \
    --Out                                               \
    --author    "Mr. foo"                               \
    --email     "foo@example.com"                       \
    --title     "This is manual page of page BAR"       \
    --html-body LANG=en                                 \
    --button-prev  previous.html                        \
    --button-top   index.html                           \
    --buttion-next next.html                            \
    --document  http://example.com/dir/this-page.html   \
    --url       manual.html                             \
    --css-code-bg                                       \
    --css-code-note '(?:Note|Notice|Warning):'          \
    --html-frame                                        \
    --disclaimer-file   $HOME/txt/my-html-footer.txt    \
    --meta-keywords    "language-en,manual,program"     \
    --meta-description "Bar program to do this that and more of those" \
    manual.txt

To check links and print status of all links in par with the http error
message (most verbose):

    % t2html --link-check file.txt | tee link-error.log

To print only problematic links:

    % t2html --link-check --quiet file.txt | tee link-error.log

To print terse output in egep -n like manner: line number, link and
error code:

    % t2html --link-check-single --quiet file.txt | tee link-error.log

To split large document into pieces, and convert each piece to HTML:

    % t2html --split1 --split-name file.txt | t2html --simple -Out

=head1 ENVIRONMENT

=over 4

=item B<EMAIL>

If environment variable I<EMAIL> is defined, it is used in footer for
contact address. Option B<--email> overrides environment setting.

=item B<LANG>

The default language setting for switch C<--language> Make sure the
first two characters contains the language definition, like in:
LANG=en.iso88591

=back

=head1 SEE ALSO

perl(1) html2ps(1) htmlpp(1)

=head2 Related programs

Jan Kärrman <jan@tdb.uu.se> has written Perl html2ps which was 2004-11-11
available at http://www.tdb.uu.se/~jan/html2ps.html

HTML validator is at http://validator.w3.org/

iMATIX created htmlpp which is available at http://www.imatix.com/

Emacs minor mode to write documents based on TF layout is available. See
package tinytf.el in project http://freshmeat.net/projects/emacs-tiny-tools

=head2 Standards

RFC B<1766> contains list of langauge codes at
http://www.rfc.net/

Latest HTML/XHTML and CSS specifications are at http://www.w3c.org/

=head2 ISO standards

B<639> Code for the representation of the names of languages
http://www.oasis-open.org/cover/iso639a.html

B<3166> Standard Country Codes
http://www.niso.org/3166.html and
http://www.netstrider.com/tutorials/HTMLRef/standards/

=head1 BUGS

The implementation was originally designed to work linewise, so it is
unfortunately impossible to add or modify any existing feature to look for
items that span more than one line.

At the time being, it is not to be expect the option B<--Xhtml> to
produce syntactically valid markup.

=head1 SCRIPT CATEGORIES

CPAN/Administrative
html

=head1 PREREQUISITES

No additional CPAN modules needed for text to HTML conversion. If link
check feature is used to to validate URL links, then following modules are
needed from CPAN C<use LWP::UserAgent> C<HTML::FormatText> and
C<HTML::Parse>

=head1 COREQUISITES

If module C<LWP::UserAgent> is available, program can be used to verify the
URL links.

If you module C<HTML::LinkExtractor> is available, it is used
instead of included link extracting algorithm.

=head1 OSNAMES

C<any>

=head1 AVAILABILITY

Homepage is at http://freshmeat.net/projects/perl-text2html

=head1 AUTHOR

Copyright (C) 1996-2006 Jari Aalto. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself or in
terms of Gnu General Public license v2 or later.

This documentation may be distributed subject to the terms and
conditions set forth in GNU General Public License v2 or later; or, at
your option, distributed under the terms of GNU Free Documentation
License version 1.2 or later (GNU FDL).

=cut

sub Help (;$ $)
{
    my $id   = "$LIB.Help";
    my $msg  = shift;  # optional arg, why are we here...
    my $type = shift;  # optional arg, type

    if ( $type eq -html )
    {
        $debug  and  print "$id: -html option\n";
        pod2html $PROGRAM_NAME;
    }
    elsif ( $type eq -man )
    {
        $debug  and  print "$id: -man option\n";

        eval "use Pod::Man";
        $EVAL_ERROR  and  die "$id: Cannot generate Man: $EVAL_ERROR";

        my %options;
        $options{center} = 'Perl Text to HTML Converter';

        my $parser = Pod::Man->new(%options);
        $parser->parse_from_file($PROGRAM_NAME);
    }
    else
    {
        $debug  and  print "$id: no options\n";

        pod2text $PROGRAM_NAME;
        print "\n\n"
        , "Default CSS and JAVA code inserted to the beginning of each file\n"
        , "See option --css-file to replace default CSS.\n"
        , JavaScript()
        ;
    }

    if ( defined $msg )
    {
        print $msg;
        exit 1;
    }

    exit 0;
}

# }}}
# {{{ misc

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return minimum value
#
#   INPUT PARAMETERS
#
#       LIST
#
#   RETURN VALUES
#
#       $number
#
# ****************************************************************************

sub Min (@)
{
    ( sort{$a <=> $b} @ARG )[0];
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Check if content looks like HTML
#
#   INPUT PARAMETERS
#
#       $arrayRef   reference to list.
#
#   RETURN VALUES
#
#       $status     True, if looks like HTML or XML
#
# ****************************************************************************

sub IsHTML ($)
{
    my $id = "$LIB.IsHTML";
    my ($arrRef) = @ARG;

    #   Search first 10 lines or lesss if there is not that many
    #   lines in array.

    local $ARG;
    my    $ret = 0;

    unless ( defined $arrRef )
    {
        warn "$id: [ERROR] arrRef is not defined";
        return;
    }

    for ( @$arrRef[0 .. Min(10, scalar(@$arrRef) -1) ]   )
    {
        if ( /<\s*(HTML|XML)\s*>/i )
        {
            $ret = 1;
            last;
        }
    }

    $debug  and  print "$id: RET [$ret]\n";

    $ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Load URL support libraries
#
#   INPUT PARAMETERS
#
#       none
#
#   RETURN VALUES
#
#       0       Error
#       1       Ok, support present
#
# ****************************************************************************

sub LoadUrlSupport ()
{
    my $id       = "$LIB.LoadUrlSupport";
    my $error    = 0;

    local *LoadLib = sub ($)
    {
        my $lib            = shift;
        local $EVAL_ERROR  = '';
        eval "use $lib";

        if ( $EVAL_ERROR )
        {
            warn "$id: $lib is not available [$EVAL_ERROR]\n";
            $error++;
        }
    };

    LoadLib( "LWP::UserAgent");
    LoadLib( "HTML::Parse");
    LoadLib( "HTML::FormatText");

    return 0 if $error;
    1;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Convert to Unix or dos styled path
#
#   INPUT PARAMETERS
#
#       $path       Path to convert
#       $unix       If non-zero, convert to unix slashes. If missing or zero,
#                   convert to dos paths.
#       $tail       if set, make sure there is trailing slash or backslash
#
#   RETURN VALUES
#
#       $           New path
#
# ****************************************************************************

sub PathConvert ( $ ; $ )
{
    my $id           = "$LIB.PathConvert";
    local ( $ARG   ) = shift;
    my    ( $unix  ) = shift;
    my    ( $trail ) = shift;

    if ( defined $unix )
    {
        s,\\,/,g;                   #font s/

        if ( $trail )
        {
            s,/*$,/,;               #font s/
        }
        else
        {
            s,/+$,,;
        }
    }
    else
    {
        s,/,\\,g;                   #fonct s/

        if ( $trail )
        {
            s,\\*$,\\,;
        }
        else
        {
            s,\\+$,,;
        }
    }

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return HOME location if possible. Guess, if cannot determine.
#
#   INPUT PARAMETERS
#
#       None
#
#   RETURN VALUES
#
#       $dir
#
# ****************************************************************************

sub GetHomeDir ()
{
    my $id = "$LIB.GetHomeDir";

    my $ret;

    unless ( defined $HOME )
    {
        print "$id: WARNING Please set environement variable HOME"
            , " to your home directory location. In Win32 This might be c:/home"
            ;
    }

    if ( defined $HOME )
    {
        $ret = $HOME;
    }
    else
    {
        local $ARG;
        for ( qw(~/tmp /tmp c:/temp)  )
        {
            -d  and   $ret = $ARG, last;
        }
    }

    $debug   and   warn "$id: RETURN $ret\n";
    $ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Debug function: Print content of an array
#
#   INPUT PARAMETERS
#
#       $title      String to name the array or other information
#       \@array     Reference to an Array
#       $fh         [optional] Filehandle
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub PrintArray ($$;*)
{
    my $id = "$LIB.PrintArray";
    my ($title, $arrayRef, $fh) = @ARG;

    if ( defined $arrayRef )
    {
        $fh       = $fh || \*STDERR;
        my $i     = 1;
        my $count = @$arrayRef;

        print $fh "\n ------ ARRAY BEG $title\n";

        for ( @$arrayRef )
        {
            print $fh "[$i/$count] $ARG\n";
            $i++;
        }

        print $fh " ------ ARRAY END $title\n";
    }
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Print Array
#
#   INPUT PARAMETERS
#
#       $name       The name of the array
#       @array      array itself
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub PrintArray2 ( $ @ )
{
    my $id = "$LIB.PrintArray";
    my ( $name, @arr) = @ARG;

    local $ARG;

    my $i     = 0;
    my $count = @arr;

    warn "$id: $name is empty"  if  not @arr;

    for ( @arr )
    {
        warn "$id: $name\[$i\] = $ARG/$count\n";
        $i++;
    }
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Debug function: Print content of a hash
#
#   INPUT PARAMETERS
#
#       $title      String to name the array or other information
#       \%array     Reference to a hash
#       $fh         [optional] Filehandle. Default is \*STDOUT
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub PrintHash ($$;*)
{
    my $id = "$LIB.PrintHash";
    my ( $title, $hashRef, $fh ) = @ARG;

    $fh = $fh || \*STDOUT;

    my ($i, $out) = (0, "");

    print $fh "\n ------ HASH $title -----------\n";

    for ( sort keys %$hashRef )
    {
        if ( $$hashRef{$ARG} )
        {
            $out = $$hashRef{ $ARG };

            if ( ref $out eq  "ARRAY" )
            {
                $out = "ARRAY => @$out";
            }
        }
        else
        {
            $out = "<undef>";
        }
        print $fh "$i / $ARG = $out \n";
        $i++;
    }
    print $fh " ------ END $title ------------\n";
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Check that email variables is good. if not ok.
#
#   INPUT PARAMETERS
#
#       $email
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub CheckEmail ($)
{
    my $id    = "$LIB.CheckEmail";
    my $email = shift;

    $debug  and  print "$id: check [$email]\n";

    not defined $email  and  Help "--email missing";

    if  ( $email =~ /^\S*$/ )         # Contains something
    {
        if  ( $email !~ /@/  or  $email =~ /[<>]/ )
        {
            die "Invalid EMAIL [$email]. It must not contain characters <> "
              , "or you didn't include \@\n"
              , "Example: me\@example.com"
              ;
        }
    }
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Remove Headers from the text array.
#
#   INPUT PARAMETERS
#
#       \@array     Text
#
#   RETURN VALUES
#
#       \@array
#
# ****************************************************************************

sub DeleteEmailHeaders ($)
{
    my $id    = "$LIB.DeleteEmailHeaders";
    my ($txt) = @ARG;

    unless ( defined $txt )
    {
        warn "$id: \$txt is not defined";
        return;
    }

    my ( @array, $body);
    my $line = @$txt[0];

    if ( $line !~ /^[-\w]+:|^From/ )
    {
        $debug  and print "$id: Skipped, no email ", @$txt[0];
        @array = @$txt;
    }
    else
    {
        for $line ( @$txt )
        {
            next if   $body == 0  and  $line !~ /^\s*$/;

            unless ( $body )
            {
                $body = 1;
                next;                           # Ignore one empty line
            }

            push @array, $line;
        }
    }

    \@array;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Make clickable url
#
#   INPUT PARAMETERS
#
#       $ref        url reference or "none"
#       $txt        text
#       $attr       [optional] additional attributes
#
#   RETURN VALUES
#
#       $string     html code
#
# ****************************************************************************

sub MakeUrlRef ($$;$)
{
    my $id = "$LIB.MakeUrlRef";
    my( $ref, $txt, $attr ) = @ARG;

    qq(<a href="$ref" $attr>$txt</A>);
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Make Picture URL tag
#
#   INPUT PARAMETERS
#
#       $ref        url reference or "none"
#       $txt        text
#       $attr       [optional] additional IMG attributes
#       $align      [optional] How to align picture: "left", "right",
#       $count      [optional] Picture number
#
#   RETURN VALUES
#
#       $string     html code
#
# ****************************************************************************

{
    my $staticReference = "";

sub MakeUrlPicture ( % )
{
    my $id = "$LIB.MakeUrlPicture";

    my %arg     = @ARG;
    my $ref     = $arg{-url};
    my $txt     = $arg{-text};
    my $attr    = $arg{-attrib};
    my $align   = $arg{-align};
    my $nbr     = $arg{-number};

    if ( not defined $align  or  not $align )
    {
        $align  = "left";
    }

    unless ( $staticReference )
    {
        $staticReference = Language( -pic);
    }

    my $picText;
    $picText = "$staticReference $nbr. " if $nbr;

    my $alt;
    $alt = qq(alt="[$picText $ref]")  if  $PICTURE_ALT;

    #  td     .. align="center" valign="middle"
    #  table  .. width="220" height="300"
    #  img    .. width="180" height="250"

    my $ret = << "EOF";
<p>
    <a name="$staticReference$nbr" id="$staticReference$nbr"></a>
    <table>
        <tr> <td align="$align" valign="middle">
                 <img src="$ref"
                      border="0"
                      $alt
                      $attr
                      >
             </td>
        </tr>
        <tr> <td>
                 <div class="picture">
                 $picText$txt
                 </div>
             </td>
        </tr>
    </table>
EOF

    $ret;
}}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Check if Module is available.
#
#   INPUT PARAMETERS
#
#       $module     Like 'LWP::UserAgent'
#
#   RETURN VALUES
#
#       0       Error
#       1       Ok, Module is present
#
# ****************************************************************************

sub CheckModule ($)
{
    my $id       = "$LIB.CheckModule";
    my ($module) = @ARG;

    #   exists $INC{ $module );

    eval "use $module";
    $debug  and  warn "$id: $module => eval [$EVAL_ERROR] \n";

    return  0  if $EVAL_ERROR;
    1;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Translate html back tho HTML href
#       &lt;a href=&quot;... => <a href="...
#
#   INPUT PARAMETERS
#
#       $line   html
#
#   RETURN VALUES
#
#       $line   text
#
# ****************************************************************************

sub XlatHtml2href ($)
{
    my $id = "$LIB.XlatHtml2href";
    local ($ARG) = @ARG;

    s{&lt;A HREF(.*?)&gt;}
    {
        "<a href" . XlatHtml2tag($1) .  ">";
    }egi;

    s,&lt;/a&gt;,</a>,gi;

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Translate html to text
#
#   INPUT PARAMETERS
#
#       $line   html
#
#   RETURN VALUES
#
#       $line   text
#
# ****************************************************************************

sub XlatHtml2tag ($)
{
    my    $id   = "$LIB.XlatHtml2tag";
    local $ARG  = shift;

    #   According to "Mastering regular expressions: O'Reilly", the
    #   /i is slower than charset []
    #
    #       s/a//i      is slow
    #       s/[aA]//    is faster

#    s,»,,g;

    s,&amp;,\&,gi;
    s,&gt;,>,gi;
    s,&lt;,<,gi;
    s,&quot;,\",gi;         # dummy-comment to close opened quote (")

    #   The special alphabet conversions

    s,&auml;,\xE4,g;    # 228 Finnish a
    s,&Auml;,\xC4,g;    # 196

    s,&ouml;,\xF6,g;    # 246 Finnish o
    s,&Ouml;,\xD6,g;    # 214

    s,&aring;,\xE5,g;   # 229 Swedish a
    s,&Aring;,\xC5,g;   # 197

    s,&oslash;,\xF8,g;  # 248 Norweigian o
    s,&Oslash;,\xD8,g;  # 216


    s,&Uuml;,\xDC,g;    # German big U diaresis
    s,&uuml;,\xFC,g;
    s,&szlig;,\xDF,g;   # German ss

    s,&sect;,§,g;       # Law-sign
    s,&frac12;,½,g;     # 1/2-sign
    s,&pound;,\xA3,g;

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Translate _word_ =word= *word* markup to HTML
#
#   INPUT PARAMETERS
#
#       $ARG        string
#       $type       -basic, Translate only the most basic things.
#
#   RETURN VALUES
#
#       $html
#
# ****************************************************************************

{
    my $staticBegBold;
    my $staticEndBold;

    my $staticBegEmp;
    my $staticEndEmp;

    my $staticBegSmall;
    my $staticEndSmall;

    my $staticBegBig;
    my $staticEndBig;

    my $staticBegRef;
    my $staticEndRef;

    my $staticBegSup;
    my $staticEndSup;

    my $staticBegQuote;
    my $staticEndQuote;

sub XlatWordMarkup ($; $)
{
    my    $id   = "$LIB.XlatWordMarkup";
    local $ARG  = shift;
    my    $type = shift;

    $debug > 2  and  print "$id: INPUT $ARG";

    return unless $ARG;

    # Prevent hash lookup, when these are set once.

    unless ( $staticBegBold )
    {
        $staticBegBold = $COLUMN_HASH{ begbold };
        $staticEndBold = $COLUMN_HASH{ endbold };

        $staticBegEmp = $COLUMN_HASH{ begemp };
        $staticEndEmp = $COLUMN_HASH{ endemp };

        $staticBegSmall = $COLUMN_HASH{ begsmall };
        $staticEndSmall = $COLUMN_HASH{ endsmall };

        $staticBegBig = $COLUMN_HASH{ begbig };
        $staticEndBig = $COLUMN_HASH{ endbig };

        $staticBegRef = $COLUMN_HASH{ begref };
        $staticEndRef = $COLUMN_HASH{ endref };

        $staticBegSup = $COLUMN_HASH{ superscriptbeg };
        $staticEndSup = $COLUMN_HASH{ superscriptend };

        $staticBegQuote = $COLUMN_HASH{ begquote };
        $staticEndQuote = $COLUMN_HASH{ endquote };
    }

    my ( $beg, $end );
    my $prefix = '(?:[\s>=+*_\"()]|^)';

    #   Handle `this' text

    $beg = $staticBegQuote;
    $end = $staticEndQuote;

    s,($prefix)\`(\S+?)\',$1$beg$2$end,g;

    $debug > 3  and  print "$id: after \`this' [$ARG]";

    #   Handle _this_ text
    #
    #   The '>' is included in the start of the regexp because this
    #   may be the end of html tag and there may not be a space
    #
    #   `;' is included because the HTML is already expanded, like
    #    quotation mark(") becomed &quot;

    $beg = $staticBegBold;
    $end = $staticEndBold;

    s,($prefix)_(\S+?)_,$1$beg$2$end,g;

    $debug > 3  and  print "$id: after _this_ [$ARG]";

    #   Handle *this* text

    $beg = $staticBegEmp;
    $end = $staticEndEmp;

    $debug > 3  and  print "$id: after *this* [$ARG]";

    if (  s,($prefix)\*(\S+?)\*,$1$beg$2$end,g  )
    {
        # For debug only
        # warn "$id:  $ARG";
        # die if m,Joka,;
    }

    $debug > 3  and  print "$id: after *this2* [$ARG]";

    #   Handle =small= text

    $beg = $staticBegSmall;
    $end = $staticEndSmall;

    s{
        ($prefix)
        =(\S+)=
     }
     {$1$beg$2$end}gx;

    $debug > 3  and  print "$id: after =this= [$ARG]";

    $beg = $staticBegBig;
    $end = $staticEndBig;

    s,($prefix)\+(\S+?)\+,$1$beg$2$end,g;

    $debug > 3  and  print "$id: after +this+ [$ARG]";

    unless ( $type eq  -basic )
    {

        #       [Mike] referred to [rfc822]

        $beg = $staticBegRef;
        $end = $staticEndRef;

        s{
           ($prefix)
           \[
              ([[:alpha:]]\S*)
           \]
           ([\s,.!?:;]|$)
         }
         {$1$beg\[$2\]$end$3}gx;

         $debug > 3  and  print "$id: after [this] [$ARG]";

        #   [Figure: this here]

        s{
            ([\s>])
             \[
                (\s*[^][\r\n]+[\s][^][\n\r]+)
             \]
         }
         {$1$beg\[$2\]$end}gx;

         $debug > 3  and  print "$id: after [this here] [$ARG]";

        #   Superscripts, raised to a "power"
        #   professor John says[1]

        $beg = $staticBegSup;
        $end = $staticEndSup;

        s{
            ([^\s\'\",!?;.(<>])
            \[
                ([^][\r\n]+)
            \]
            ([\s\,.:;]|$)
         }
         {$1$beg$2$end$3}gx;

         $debug > 3  and  print "$id: after this[superscript] [$ARG]";

    }

    $debug > 2  and  print "$id: RETURN $ARG";

    $ARG;
}}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Translate some special characters into Html codes.
#
#       See "Standard Character entity"
#       http://www.stephstuff.com/ISOCactrs4.html
#
#   INPUT PARAMETERS
#
#       $line   text
#
#   RETURN VALUES
#
#       $line   html
#
# ****************************************************************************

sub XlatTag2html ($)
{
    my    $id = "$LIB.XlatTag2html";
    local $ARG = shift;

    my $localDebug = 1  if  $debug > 5;

    $localDebug  and  print "$id: INPUT [$ARG]\n";

    return unless $ARG;

    #      Leave alone all HTML entities, like &sup2;
    s,\&(?![a-zA-z][a-z]+[123]?;|#\d\d\d;),&amp;,g;

    $localDebug  and  print "$id: -0- $ARG\n";

    unless ( /<<|>>/ )
    {
        #   You can write PURE HTML inside text like this:
        #
        #       <<table border=5 cellpadding="7">>
        #
        #   We do not want to translate this line into
        #
        #       <<table border=5 cellpadding=&quot;7&quot;>>

        s,\",&quot;,g;  # dummy-coment " to fix Emacs font-lock highlighting
    }

    #   Hand Debug. Turn this on, if converson does not work.
    #   $localDebug = 1  if /<<|>>/;

    $localDebug  and  print "$id: -1- $ARG\n";

    #   This code uses negative look-behind and looh-ahead regexp. The idea
    #   is that
    #
    #       <<html>>        is rendered as embedded <html>
    #       <some           is rendered &lt;some
    #
    #   Can't use regexp
    #
    #       s,<<(?![a-zA-Z]+>),&lt;&lt;,g;
    #
    #   Because it converts:
    #
    #       <<table border="1">
    #              |
    #              Can't know that there is not yet ">" like in <<td>>
    #
    #   Whereas this would be valid
    #
    #       cat file <<EOF

    my $re = '[^\"\'/a-zA-Z]';

    s,($re)>>,$1&gt;&gt;,go;
    s,<<($re),&lt;&lt;$1,go;

    $localDebug  and  print "$id: -2- $ARG\n";

    s,(?<!>)>(?!>),&gt;,g;
    s,(?<!<)<(?!<),&lt;,g;

    $localDebug  and  print "$id: -3-  $ARG\n";

    #   If there are still "doubled", then this is special
    #   tab <<table>>, convert it into standard HTML tag.

    s,>>,>,g;
    s,<<,<,g;

    $localDebug  and  print "$id: -4- $ARG\n";

    #   The special alphabet conversions

    s,\xE4,&auml;,g;    # 228 Finnish a
    s,\xC4,&Auml;,g;    # 196

    s,\xF6,&ouml;,g;    # 246 Finnish o
    s,\xD6,&Ouml;,g;    # 214

    s,\xE5,&aring;,g;   # 229 Swedish a
    s,\xC5,&Aring;,g;   # 197

    s,\xF8,&oslash;,g;  # 248 Norweigian o
    s,\xD8,&Oslash;,g;  # 216

    # German characters

    s,\xDC,&Uuml;,g;    # big U diaresis
    s,\xFC,&uuml;,g;
    s,\xDF,&szlig;,g;   # ss

    # French

    s,\xE9,&eacute;,g;  # e + forward accent (')
    s,\xC9,&Eacute;,g;

    # Spanish

    s,\xD1,&ntilde;,g;  # n + accent (~)
    s,\xF1,&Ntilde;,g;

    # Other signs

    s,\xA7,&sect;,g;       # Law-sign
    s,\xBD,&frac12;,g;     # 1/2-sign
    s,\xA3,&pound;,g;      # Pound

    s,\xAB,&laquo;,g;      # <<
    s,\xBB,&raquo;,g;      # >>

    $debug  and  print "$id: RET [$ARG]\n";

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Translate convertions in this program's markup to HTML.
#       Like "--" will become &ndash;
#
#   INPUT PARAMETERS
#
#       $line   text
#
#   RETURN VALUES
#
#       $line   html
#
# ****************************************************************************

sub XlatTag2htmlSpecial ($)
{
    my    $id = "$LIB.XlatTag2htmlSpecial";
    local $ARG = shift;

    return unless $ARG;

    #  --   long dash

    s,(\s)--(\s|$),$1&ndash;$2,g;

    #  +-40

    s,([+][-]|[-][+])(\d),&plusmn;$2,g;

    #   European Union currency: 400e

    s,(\d)e(\s|$),$1 &euro;$2,g;

    #   Some frequent tokens, like
    #   (C) Copyright) sign,
    #   (R) Registered trade mark
    #   3 (0)C Celsius degrees

    s,([.\,;\s\d ])\Q(C)\E([\s\w]),$1&copy;$2,g;
    s,([.\,;\s\d ])\Q(0)\E([\s\w]),$1&deg;$2,g;
    s,([.\,;\s\d ])\Q(R)\E([\s\w]),$1&reg;$2,g;

    $debug  and  print "$id: RET [$ARG]\n";

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Translate $REF special markers to clickable html.
#       A reference link looks like
#
#           #REF link-to; shown text;
#
#   INPUT PARAMETERS
#
#       $line
#
#   RETURN VALUES
#
#       $html
#
# ****************************************************************************

sub XlatRef ($)
{
    my $id     = "$LIB.XlatRef";
    local $ARG = shift;

    if (  /(.*)#REF\s+(.*)\s*;(.*);(.*)/ )
    {
        # There already may be absolute reference, check it first
        #
        #   http:/www.example.com#referece_here

#       $s2 = "#$s2"  if not /(\#REF.+\#)/ and /ftp:|htp:/;

        $debug  and  print "$id: #REF--> [$1]\n [$2]\n [$3]\n [$ARG]";

        $ARG = $1 .  MakeUrlRef($2, $3) . $4;

        unless ( $ARG =~ /#|http:|file:|news:|wais:|ftp:/ )
        {
            warn "$id: Suspicious REF. Did you forgot # or http?\n\t$ARG"
        }

        $debug  and  print "$id:LINE[$ARG]";

    }
    elsif ( /#REF.+#/ )
    {
        warn "$id: Suspicious #REF format [$ARG]. Must contain hash-sign(#)";
    }

    $debug > 2  and  print "$id: RET [$ARG]\n";

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Translate PIC special markers to pictures
#
#           #PIC link-to; caption text; image-attributes;
#
#   INPUT PARAMETERS
#
#       $line
#
#   RETURN VALUES
#
#       $html
#
# ****************************************************************************

{

    my $staticPicCount = 0;

sub XlatPicture ($)
{

    my $id     = "$LIB.XlatPicture";
    local $ARG = shift;

    if ( /(.*)#PIC\s+([^#]+\S)\s*#\s*(.*)#\s*(.*)#\s*(.*)#(.*)/ )
    {
        my ($before, $url, $text, $attr, $align, $rest)
            = ($1, $2, $3, $4, $5, $6);

        #   This is used to number each picture as it appears

        $staticPicCount++;

        # There already may be absolute reference, check it first
        #
        #   http:/www.example.com#referece_here

        $debug and warn "$id: #PIC--> \$1[$1]\n\$2[$2]\n\$3[$3]\nLINE[$ARG]";

        my $pictureHtml = MakeUrlPicture
            -url        => $url
            , -text     => XlatWordMarkup($text, -basic)
            , -attrib   => $attr
            , -align    => $align
            , -number   => $staticPicCount
            ;

        $ARG = $before .  $pictureHtml . $rest;

        #   Try finding .gif .jpg .png or something ...

        unless ( m,\.[a-z][a-z][a-z],i )
        {
            warn "$id: Suspicious #PIC [$ARG]. Did you forgot .png .jpg ...?"
        }

        $debug  and  warn "$id:LINE[$ARG]";
    }
    elsif ( /#PIC.*#/ )
    {
        warn "$id: Suspicious #PIC format [$ARG]. Must have 3 separators(#)";
    }

    $debug > 2   and   print "$id: RET [$ARG]\n";

    $ARG;
}}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Search all named directived that start with #T2HTML-<directive>
#       and return their values. The lines are removed from the text.
#
#           #T2HTML-TITLE  This is the HTML file title
#           #T2HTML-EMAIL  foo@somewhere.net
#           ...
#
#   INPUT PARAMETERS
#
#       @content        The HTML file.
#
#   RETURN VALUES
#
#       \%directives    key => [ value, value ...]
#       @content        Lines matching #T2HTML have been removed.
#
# ****************************************************************************

sub XlatDirectives (@)
{
    my $id     = "$LIB.XlatDirectives";
    my ( @content ) = @ARG;

    ! @content  and die "$id: \@content is empty";

    local $ARG;
    my (@ret, %hash);

    $debug  and  print "$id: line count: ", scalar @content, "\n";

    for ( @content )
    {
        if ( /^(.*)\s*#T2HTML-(\S+)\s+(.*\S)/i )
        {
            $debug  > 2 and  warn "$id: if-1a [$ARG]\n";

            my ($line, $name, $value) = ($1, $2, $3);

            $debug  > 2 and  warn "$id: if if-2b ($name,$value,[$line])\n";

            next if $name =~ /comment/i;

            push @ret, $line   if  $line =~ /\S/;
            $name = lc $name;


            $verb > 1  and  print "$id: if-1c [$name] = [$value]\n";

            unless ( defined $hash{$name} )
            {
                $hash{ $name } = [$value];
            }
            else
            {
                my $arrRef = $hash{ $name };
                push @$arrRef, $value;
                $hash{ $name } = $arrRef;
            }
        }
        elsif ( /^(.*)\s*#T2HTML-(\S+)/i )
        {
            #  Empty directive

            $debug  and print "$id: $ARG";

            my $line = $1;

            $debug > 2  and warn "$id: elsif 2 [$line]\n";

            push @ret, $line   if  $line =~ /\S/;
        }
        else
        {
            push @ret, $ARG;
        }
    }


    $debug  and  PrintHash("$id: RET", \%hash);


    \%hash, @ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Check if we accept URL. Any foo|bar|baz|quu|test or the like
#       is discarded. In exmaples, you should use "example" domain
#       that is Valud, but non-sensial. (See RFCs for more)
#
#           http://www.example.com/
#           ftp:/ftp.example.com/
#
#   INPUT PARAMETERS
#
#       $url
#
#   RETURN VALUES
#
#       1, 0
#
# ****************************************************************************

sub AcceptUrl($)
{
    if ( $ARG[0] !~ m,\b(foo
                         |baz
                         |quu[zx])\b
                      |:/\S*\.?example\.
                      |example\.com
                      |:/test\.

                    ,x
         )
    {
        1;
    }
    else
    {
        0;
    }
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Translate URL special markers for inline texts
#
#           #URL<http-reference><inline text>
#
#   INPUT PARAMETERS
#
#       $line
#
#   RETURN VALUES
#
#       $html
#
# ****************************************************************************

sub XlatUrlInline ($)
{
    my $id     = "$LIB.XlatUrlInline";
    local $ARG = shift;

    s
    {
      ^(.*)
      \#URL \s*
      &lt; (.+?) &gt; \s*
      &lt; (.+?) &gt;
      (.*)
    }
    {
        my $before = $1;
        my $url    = $2;
        my $inline = $3;
        my $after  = $4;

        qq($before<a href="$url">$inline</a>$after);

    }gmex;

    $debug > 2  and  print "$id: RET [$ARG]\n";

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Translate url references to clickable html format
#
#   INPUT PARAMETERS
#
#       $line
#
#   RETURN VALUES
#
#       $html
#
# ****************************************************************************

sub XlatUrl ($)
{

    my $id     = "$LIB.XlatUrl";
    local $ARG = shift;

    my ($url, $pre);

    #  Already handled?

    return $ARG if /a href/i;

    s
    {
        ([^\"]?)           # Emacs font-lock comment to terminate opening "
        (?<!HREF=\")       # Already handled by XlatUrlInline()
        ((?:file|ftp|http|news|wais|mail|telnet):

         #  urls can contain almost anything,
         #  BUT the last character grabbed in text must not be period,
         #  colon etc. because they canät be distinguished from regular text
         #  tokens.
         #
         #      See url http://example.com/that.txt. New sentence starts here.
         #
         #  It would be better to write
         #
         #      See url <http://example.com/that.txt>. New sentence starts here.
         #
         [^][\s<>]+[^\s,.!?;:<>])
    }
    {
        $pre = $1;
        $url = $2;

        $debug > 4  and  print "$id: PRE=[$pre] URL=[$url]\n";

        #  Unfortunately the Link that is passed to us has already
        #  gone through conversion of "<" and ">" as in
        #  <URL:http://example.com/>  so we must treat the ending
        #  ">" as a separate case

        my $last = "";

        if ( $url =~ /(&gt;?.*)/i )
        {
            $last = $1;
            $url  =~ s/&gt;?.*//;
        }

        #   Do not make -http://some.com clickable. Remove "-" in
        #   front of the URL.

        my $clickable = 1;

        if ( $pre =~ /-/ )
        {
            $clickable = 0;
            $pre       = "";
        }

        $debug > 4  and print "$id: ARG=[$ARG] pre=[$pre] url=[$url] "
                        , " click=$clickable, accept=", AcceptUrl $url, "\n";

        if ( not $clickable  or  not AcceptUrl $url  )
        {
            $pre . $url . $last ;
        }
        else
        {
            #   When we make HREF target to point to "_top", then
            #   the destination page will occupy whole browser window
            #   automatically and delete any existing frames.
            #
            #   --> Destination may freely set up its own frames

            my $opt =  qq!target="_top"! ;
            $opt    = ''; # disabled for now.

            join ''
                , $pre
                , MakeUrlRef( $url, $url, $opt )
                , $last
                ;
        }
    }egix;

    $debug > 2  and  print "$id: RET=[$ARG]\n";

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Translate email references to clickable html format
#
#   INPUT PARAMETERS
#
#       $line
#
#   RETURN VALUES
#
#       $html
#
# ****************************************************************************

sub XlatMailto ($)
{
    my    $id  = "$LIB.Mailto";
    local $ARG = shift;

    #   Handle Mail references, we need while because there may be
    #   multiple mail addresses on the line
    #
    #   A special case; in text there may be written like these. They are NOT
    #   clickable email addresses.
    #
    #    References: <5dfqlm$m50@basement.replay.com>
    #    Message-ID: <5dko56$1lv$1@news02.deltanet.com>
    #
    #   Ignore certain email addresses like
    #   foo@example.com  bar@example.com ... that are used as examples
    #   in the document.
    #
    #   Ignore also any address that is like
    #   -<addr@example.com>         Leading dash
    #    < addr@example.com>        space follows character <

    s
    {
        (^|.)                           # must not start with "-"

        &lt;                            # html <  tag.
             ([^ \t$<>]+@[^ \t$<>]+)
        &gt;
    }
    {
        my $pre       = $1;
        my $url       = $2;
        my $clickable = 1;

        if ( $pre eq '-' )
        {
            $clickable = 0;
            $pre       = "";
        }

        if ( not $clickable  or  not AcceptUrl $url )
        {
            $pre . $url;
        }
        else
        {
            $pre . "<em>" . MakeUrlRef( "mailto:$url" , $url) . "</em>"
        }
    }egx;

    $debug > 2  and  print "$id: RET [$ARG]\n";

    $ARG;
}


# ****************************************************************************
#
#   DESCRIPTION
#
#       Return standard Unix date
#
#           Tue, 20 Aug 1999 14:25:27 GMT
#
#       The HTML 4.0 specification gives an example date in that format in
#       chapter "Attribute definitions".
#
#   INPUT PARAMETERS
#
#       $       How many days before expiring
#
#   RETURN VALUES
#
#       $str
#
# ****************************************************************************

sub GetExpiryDate (;$)
{
    my $id        = "$LIB.GetExpiryDate";
    my $days      =  shift || 60;

    #   60 days Expiry period, about two months

    gmtime(time + 60*60*24 * $days)  =~ /(...)( ...)( ..)( .{8})( ....)/;
    "$1,$3$2$5$4 GMT";
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return ISO 8601 date YYYY-MM-DD HH:MM
#
#   INPUT PARAMETERS
#
#       none
#
#   RETURN VALUES
#
#       $str
#
# ****************************************************************************

sub GetDate ()
{
    my $id        = "$LIB.GetDate";

    my (@time)    = localtime(time);
    my $YY        = 1900 + $time[5];
    my ($DD, $MM) = @time[3..4];
    my ($mm, $hh) = @time[1..2];

    $debug  and  warn "$id: @time\n";

    #   Count from zero, That's why +1.

    sprintf "%d-%02d-%02d %02d:%02d", $YY, $MM + 1, $DD, $hh, $mm;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return ISO 8601 date YYYY-MM-DD HH:MM
#
#   INPUT PARAMETERS
#
#       none
#
#   RETURN VALUES
#
#       $str
#
# ****************************************************************************

sub GetDateYear ()
{
    my $id        = "$LIB.GetDateYear";

    my (@time)    = localtime(time);
    my $YY        = 1900 + $time[5];

    $debug  and  warn "$id: @time\n";

    #   I do not know why Month(MM) is one less that the number month
    #   in my calendar. That's why +1. Does it count from zero?

    $YY;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return approproate sentence in requested language.
#
#   INPUT PARAMETERS
#
#       $token      The name of the token to get. e.g "-toc"
#
#   RETURN VALUES
#
#       $string     String in the set language. See --language switch
#
# ****************************************************************************

sub Language ($)
{
    my $id   = "$LIB.Language";
    XlatTag2html $LANGUAGE_HASH{ shift() }{ $LANG_ISO };
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Add string to filename. file.html --> fileSTRING.html
#
#   INPUT PARAMETERS
#
#       $file       filename
#       $string     string to add to the adn of name, but before extension
#       $extension
#
#   RETURN VALUES
#
#       $file
#
# ****************************************************************************

sub FileNameChange ($$;$)
{
    my $id              = "$LIB.FileNameChange";
    my ( $file, $string , $ext ) = @ARG;

    my ( $filename, $path, $extension ) = fileparse $file, '\.[^.]+$'; #font '

    my $ret = $path . $filename . $string . ($ext or $extension);

    $debug  and  print "$id: RET $ret\n";

    $ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return frame's file name
#
#   INPUT PARAMETERS
#
#       $type       "-frm", "-toc", "-txt"
#
#   USE GLOBAL
#
#       $ARG_PATH
#
#   RETURN VALUES
#
#       $file
#
# ****************************************************************************

sub FileFrameName ($)
{
    my $id      = "$LIB.FileFrameName";
    my $type    = shift;

    if ( $ARG_PATH ne '' )
    {
        $debug  and  print "$id: $ARG_PATH + $type + .html\n";
        FileNameChange $ARG_PATH, $type, ".html";
    }
}

sub FileFrameNameMain() { FileFrameName ""          }
sub FileFrameNameToc()  { FileFrameName "-toc"      }
sub FileFrameNameBody() { FileFrameName "-body"     }

# ****************************************************************************
#
#   DESCRIPTION
#
#       CLOSURE. Return new filename file.txt-NNN based on initial values.
#       Each NNN is incremented during call.
#
#   INPUT PARAMETERS
#
#       $file       starting filename
#       $heading    Flag. If 1, generate name from headings, instead of
#                   numeric names.
#
#   RETURN VALUES
#
#       &Sub($)     Anonymous subroutine that must be called with string.
#
# ****************************************************************************

sub GeneratefileName ($;$)
{
    my $id       = "$LIB.GeneratefileName";
    my ($file, $headings ) = @ARG;

    if ( $headings )
    {
        return sub
        {
            my $line = shift;

            not defined $line
                and croak "You must pass one ARG";

            not $line =~ /[a-z]/
                and croak "ARG must contain some words. Cannot make filename";

            sprintf "$file-%s", MakeHeadingName($line);
        }
    }
    else
    {
        my $i = 0;
        return sub
        {
            #   this function ignores passed ARGS
            sprintf "$file-%03d", $i++;
        }

    }
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Write content to file
#
#   INPUT PARAMETERS
#
#       $file
#       \@content   reference to array (text) or plain string.
#
#   RETURN VALUES
#
#       @           list of filenames
#
# ****************************************************************************

sub WriteFile ($$)
{
    my $id             = "$LIB.WriteFile";
    my ($file, $value) = @ARG;

    unless ( defined $value )
    {
        warn "$id: \$value is not defined";
        return;
    }

    open  my $FILE, "> $file" or die "$id: Cannot write to [$file] $ERRNO";
    binmode $FILE;

    my $type =  ref $value;

    $debug  and  warn "$id: TYPE [$type]\n";

    if ( $type eq "ARRAY" )
    {
        print $FILE @$value;
    }
    elsif ( not $type )
    {
        print $FILE $value;
    }

    close $FILE;

    $debug  and  warn "$id: Wrote $file\n";
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Split text into separate files file.txt-NNN, search REGEXP.
#       Files are ruthlessly overwritten.
#
#   INPUT PARAMETERS
#
#       $regexp     If found. The line is discarded and anything gathered
#                   for far is printed to file. This is the Split point.
#       $file       Used in split mode only to generate multiple files.
#       $useNames   Flag. If set compose filenames based on REGEXP split.
#       \@content   text
#
#   RETURN VALUES
#
#       @           list of filenames
#
# ****************************************************************************

sub SplitToFiles ($ $$ $)
{
    my $id = "$LIB.SplitToFiles";
    my ($regexp, $file, $useNames, $array) = @ARG;

    unless ( defined $array )
    {
        warn "$id: [ERROR] \$array is not defined";
        return;
    }

    my    (@fileArray, @tmp);
    my    $FileName = GeneratefileName $file, $useNames;
    local $ARG;

    for ( @$array )
    {
        if ( /$regexp/o && @tmp )
        {
            #   Get the first line that matched and use it as filename
            #   base

            my ($match) = grep /$regexp/o, @tmp;

            my $name = &$FileName( $match );
            WriteFile $name, \@tmp;

            @tmp = ();
            push @tmp, $ARG;

            push @fileArray, $name;
        }
        else
        {
            push @tmp, $ARG;
        }
    }

    if ( @tmp )                                 # last block
    {
        my $name = &$FileName( $tmp[0] );
        WriteFile $name, \@tmp;

        push @fileArray, $name;
    }

    @fileArray;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Expand environmetn variables in STRING.
#
#   INPUT PARAMETERS
#
#       $str        String to process
#
#   RETURN VALUES
#
#       $out        Expanded
#
# ****************************************************************************

sub EnvExpand ($)
{
    my $id      = "$LIB.EnvExpand";
    local($ARG) = @ARG;

    $debug and  print "$id: INPUT [$ARG]\n";

    #   Substitution must happen so that longest match takes
    #   precedence.

    my $val;

    for my $key ( sort {length($b) <=> length($a)} keys %ENV )
    {
        $val = $ENV{$key};

        s/\$$key/$val/;
    }

    $debug and  print "$id: RET [$ARG]\n";

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Remove everything up till <body> and after </body>. This effectively
#       makes it possible to have clean HTML whis is not a "page" any more.
#       The portion marked with !! to the right is preserved, everything else
#       is stripped.
#
#           <html>
#             <head>
#               ...
#             </head>
#             <body>
#               This text                 !!
#               And more of this          !!
#             </body>
#           </html>
#
#   INPUT PARAMETERS
#
#       $str        String to process
#
#   RETURN VALUES
#
#       $content
#
# ****************************************************************************

sub RemoveHTMLaround ($)
{
    my $id      = "$LIB.RemoveHTML";
    local($ARG) = @ARG;

    $debug > 2  and  print "$id: [$ARG]\n";

    #   Delete everything up til <body>
    #   Delete everything after  </body>

    s,^.+<\s*body\s*>,,i;
    s,<\s*/\s*body\s*>.*,,i;

    #   Malformed web paged do not even bother to use BODY, so
    #   try if there are HEAD or HTML and kill those

    s,^.+<\s*/\s*head\s*>,,i;
    s,^.*<\s*html\s*>.*,,i;
    s,<\s*/\s*html\s*>.*,,i;

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return content of URL as string.
#
#   INPUT PARAMETERS
#
#       $url        File path or HTTL URL.
#
#   RETURN VALUES
#
#       $content    This value is empty if couldn't read URL.
#
# ****************************************************************************

sub UrlInclude (%)
{
    my $id    = "$LIB.UrlInclude";

    my %arg     = @ARG;
    my $dir     = $arg{-dir};
    my $url     = $arg{-url};
    my $mode    = $arg{-mode};

    $debug  and  print "$id: url [$url] dir [$dir] mode [$mode]\n";

    my $ret;

    if ( $MODULE_LWP_OK  and  $url =~ m,http://,i )
    {
        my $ua       = new LWP::UserAgent;
        my $req      = new HTTP::Request( GET => $url);
        my $response = $ua->request( $req );
        my $ok       = $response->is_success();

        $debug     and  print "$id: GET status $ok\n";

        if ( $ok )
        {
            $ret = $response->content();

            $debug > 2 and  print "$id: content BEFORE =>\n$ret\n";

            $ret = RemoveHTMLaround $ret;
        }
    }
    else
    {
        # 1) There is no path, so use current directory
        # 2) It start with relative path ../

        if ( $dir  and  ($url !~ m,[/\\],  or  $url =~ m,^[.],, ) )
        {

            $debug > 2 and  print "$id: dir added: $dir + $url\n";
            $url = "$dir/" . $url;
        }

        local *FILE;
        $url = EnvExpand $url;

        unless ( open FILE, "< $url" )
        {
            $verb  and  warn "Cannot open '$url' $ERRNO";
            return;
        }

        $ret = join '', <FILE>;
        close FILE;

        if ( $url =~ /\.s?html?/ )
        {
            $ret = RemoveHTMLaround $ret;
        }

        unless ( $mode )
        {
            $ret = DoLineUserTags($ret);
            $ret = XlatTag2html $ret;
            $ret = XlatRef $ret;
            $ret = XlatPicture $ret;

            $ret = XlatUrlInline $ret;
            $ret = XlatUrl $ret;
            $ret = XlatMailto $ret;
            $ret = XlatWordMarkup $ret;
        }
    }

    $debug > 2 and  print "$id: RET =>\n$ret\n";

    $ret;
}

# }}}
# {{{ misc - make

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return BASE. must be inside HEAD tag
#
#   INPUT PARAMETERS
#
#       $file       html file
#       $attrib     Additional attributes
#
#   USES GLOBAL
#
#       $BASE_URL
#
#   RETURN VALUES
#
#       $html
#
# ****************************************************************************

sub Base (;$$)
{
    my $id      = "$LIB.Base";
    my ($file, $attrib) = @ARG;

    if ( defined $BASE_URL and $BASE_URL ne '' )
    {
        qq(  <base href="$BASE_URL/$file" $attrib>\n) ;
    }
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return CSS Style sheet data without the <style> .. </style> tokens
#       The correct way to include external CSS is:
#
#           <link rel="stylesheet" type="text/css" href="/dir/my.css">
#
#   RETURN VALUES
#
#       code
#
# ****************************************************************************

sub CssData ( ; $ )
{
        local ( $ARG ) = @ARG;

        $ARG = '' unless defined $ARG;

        my $bodyFontType = '' ;

        if ( defined $CSS_FONT_TYPE )
        {
            #  Css must end to ";", Add semicolon if it's missing.
            $bodyFontType = "font-family: $CSS_FONT_TYPE";
            $bodyFontType .= ";" unless $bodyFontType =~ /;/;
        }

        my $bodyFontSize = '';

        if ( defined $CSS_FONT_SIZE )
        {
            $bodyFontSize = qq(font-size: $CSS_FONT_SIZE);
            $bodyFontSize .= ";" unless $bodyFontSize =~ /;/;
        }

        if ( /toc/i )
        {
            $bodyFontSize = $CSS_BODY_FONT_SIZE_FRAME;
        }

        return qq(

        /*

            ///////////////////////////////////////////////////////////
               NOTE    NOTE    NOTE    NOTE    NOTE    NOTE    NOTE

            This is the default CSS 2.0 generated by the program,
            please see "t2html --help" for option --script-file
            to import your own CSS and Java definitions into the page.

            XHTML note: at page http://www.w3.org/TR/xhtml1/#guidelines
            It is recommended that CSS2 with XHTML use lowercase
            element and attribute names

            This default CSS2 has been validated according to
            http://jigsaw.w3.org/css-validator/validator-uri.html.en

            To design colors, visit:
            http://www.btexact.com/people/rigdence/colours/

               NOTE    NOTE    NOTE    NOTE    NOTE    NOTE    NOTE
            ///////////////////////////////////////////////////////////

            Comments on the CSS tags:

            -   block-width: "thin" (Netscape ok, MSIE nok)

            NETSCAPE 4.05

            -  In general does not render CSS very well. Eg
               font size changes does not show up in screen.
            -  :hover property is not recognised

            NETSCAPE 4.75 as of 2000-10-01

            -  Shows garbage for stylesheet section that marked CITATION.
               (IE has no trouble to show it)

            MSIE 4.0+

            - Renders CSS very well.

            Media types

            - Netscape does not transfer the CSS element definitions to
              the "print" media as it should. They only affect Browser
              or media "screen"
            - That is why you really have to say EM STRONG ... /STRONG EM
              to get that kind of text seen in printer too. You cannot
              just define P.column7 { ... }

            The \@media CSS definition is not supported by Netscape 4.05
            I do not know if MSIE 4.0 supports it.

            So doing this would cause CSS to be ignored completely
            (never mind that CSS says the default CSS applies to "visual",
            which means both print and scree types.)

                \@media print, screen {  P.code {..}  }

            To work around that, we separate the definitions with

                P.code { .. }               // For screen

                \@media print { P.code      // for printer
                {
                    ..
                }}

            And wish that some newer browser will render it right.

        */

        /*   ///////////////////////////////////////////////// HEADINGS */

        h1.default
        {
            font-family: bold x-large Arial,helvetica,Sans-serif;
            padding-top: 10pt;
        }

        h2.default
        {
            font-family: bold large Arial,Helvetica,Sans-serif;
        }

        h3.default
        {
            font-family: bold medium Arial,Helvetica,Sans-serif;
        }

        h4.default
        {
            font-family: medium Arial,Helvetica,Sans-serif;
        }

        /*   ////////////////////////// Make pointing AHREF more visual */

        body
        {
            $bodyFontType
            $bodyFontSize

            /*
                More readable font, Like Arial in MS Word
                The background color is grey

                font-family: "verdana", sans-serif;
                background-color: #dddddd;
                foreground-color: #000000;

                Traditional "Book" and newspaper font
                font-family: "Times New Roman", serif;
            */
        }

        a:link
        {
            font-style: italic;
        }

        /*   A name=... link references */

        a.name
        {
            font-style: normal;
        }

        a:hover
        {
            color:           purple;
            background:      #AFB;
            text-decoration: none;
        }

            /* cancel above italic in TOC and Navigation buttons */

        a.btn:link
        {
            font-style: normal;
        }

            /* each link in TOC */


        a.toc
        {
            font-family: verdana, sans-serif;
            font-style: normal;
        }

        a.toc:link
        {
            font-style: normal;
        }

            /* [toc] heading button which appears in non-frame html */

        a.btn-toc:link
        {
            font-style: normal;
            font-family: verdana, sans-serif;
            /* font-size:  0.7em; */
        }

        /*  //////////////////////////////////// Format the code sections  */

        /*  MSIE ok, Netscape nok: Indent text to same level to the right  */

        blockquote
        {
            margin-right: 2em;
        }

        \@media print   { BLOCKQUOTE
        {
            margin-right: 0;
        }}

        samp.code
        {
            color: Navy;
        }

        hr.special
        {
            width: 50%;
            text-align; left;
        }

        pre
        {
            font-family:   "Courier New", monospace;
            font-size:     0.8em;
            margin-top:    1em;
            margin-bottom: 1em;
        }

        pre.code
        {
            color: Navy;
        }

        p.code, p.code1, p.code2
        {
            /*
               margin-top:     0.4em;
               margin-bottom:  0.4em;
               line-height:    0.9em;
            */

            font-family:    "Courier New", monospace;
            font-size:      0.8em;
            color:          Navy;
        }

        /* //////////////////////// tables /////////////////////////// */

        table
        {
            border: none;
            width: 100%;
            cellpadding: 10px;
            cellspacing: 0px;
        }

        table.basic
        {
                font-family:    "Courier New", monospace;
                color: Navy;
        }

        table.dashed
        {

                /* font-family: sans-serif; /*
                /* background:  #F7DE9C; */

                color: Navy;

                border-top:     1px #999999 solid;
                border-left:    1px #999999 solid;
                border-right:   1px #666666 solid;
                border-bottom:  1px #666666 solid;
                border-width:   thin;
                border-style: dashed; /* dotted */


                /* line-height: 105%; */
        }

        table.solid
        {
                font-family:    "Courier New", monospace;
                /* afont-size:      0.8em; */

                color:          Navy;

                /* font-family: sans-serif; /*
                /* background:  #F7DE9C; */

                border-top:     1px #CCCCCC solid;
                border-left:    1px #CCCCCC solid; /* 999999 */
                border-right:   1px #666666 solid;
                border-bottom:  1px #666666 solid; /* dark grey */
                /* line-height: 105%; */
        }

        /* Make 3D styled layout by thickening the boton + right. */

        table.shade-3d
        {
                font-family:    "Courier New", monospace;
                font-size:      0.8em;

                color:          #999999; /* Navy; */

                /* font-family: sans-serif; /*
                /* background:  #F7DE9C; */

                /* border-top:  1px #999999 solid; */
                /* border-left: 1px #999999 solid; */
                border-right:   4px #666666 solid;
                border-bottom:  3px #666666 solid;
                /* line-height: 105%; */
        }

        .shade-3d-attrib
        {
            /*
                F9EDCC          Light Orange
                FAEFD2          Even lighter Orange

                #FFFFCC         Light yellow, lime

            */

            background: #FFFFCC;
        }

        table tr td pre
        {
                /*  Make PRE tables "airy" */
                margin-top:    1em;
                margin-bottom: 1em;
        }

        table.shade-normal
        {
                font-family:    "Courier New", monospace;
                /* font-size:      0.9em; */
                color:          Navy;
        }

        .shade-normal-attrib
        {
            /*  grey: EAEAEA, F0F0F0 FFFFCC
                lime: F7F7DE CCFFCC
                pinkish: E6F1FD D8E9FB C6DEFA FFEEFF (light ... darker)
                slightly darker than F1F1F1: #EFEFEF;
            */
            background: #F1F1F1;
        }

        table.shade-normal2
        {
                font-family:    "Courier New", monospace;
        }

        .shade-normal2-attrib
        {
            background: #E0E0F0;
        }

        .shade-note-attrib
        {
            /*  darker is #E0E0F0; */
            /* background: #E5ECF3; */
            background: #E5ECF3;
            font-family: Georgia, "New Century Schoolbook",
                         Palatino, Verdana, Helvetica, serif;
            font-size: 0.8em;
        }

        /* ..................................... colors ................. */

        .color-white
        {
            color: Navy;
            background: #FFFFFF;
        }

        .color-fg-navy
        {
            color: navy;
        }

        .color-fg-blue
        {
            color: blue;
        }

        .color-fg-teal
        {
            color: teal;
        }

        /*   Nice combination: teal-dark, beige2 and  beige-dark */

        .color-teal-dark
        {
            color: #96EFF2;
        }

        .color-beige
        {
            color: Navy;
            background: #F7F7DE;
        }

        .color-beige2
        {
            color: Navy;
            background: #FAFACA;
        }

        .color-beige3
        {
            color: Navy;
            background: #F5F5E9;
        }

        .color-beige-dark
        {
            color: Navy;
            background: #CFEFBD;
        }

        .color-pink-dark
        {
            background: #E6F1FD;
        }

        .color-pink-medium
        {
            background: #D8E9FB;
        }

        .color-pink
        {
            /*  grey: EAEAEA, F0F0F0 FFFFCC
                lime: F7F7DE CCFFCC
                pinkish: E6F1FD D8E9FB C6DEFA FFEEFF (light ... darker)
            */
            background: #C6DEFA;
        }

        .color-pink-light
        {
            background: #FFEEFF;
        }

        .color-blue-light
        {
            background: #F0F0FF;
        }

        .color-blue-medium
        {
            background: #4A88BE;
        }

        /* ////////////////////////////////////////////// Format columns */

        p.column3
        {
            color: Green;
        }

        p.column5
        {
            color: #87C0FF;   /* shaded casual blue */
        }

        p.column6
        {
            /* #809F69 is Forest green
               But web safe colors are:
               Lighter  ForestGreen: 66CC00
               ForestGreen: #999966 669900 339900 669966

            color: #669900;
            font-family: "Goudy Old Style"
            */
            margin-left: 3em;
            font-family: Georgia, "New Century Schoolbook",
                         Palatino, Verdana, Arial, Helvetica;
            font-size:  0.9em;
        }

            /* This is so called 3rd heading */

        p.column7
        {
            font-style:  italic;
            font-weight: bold;
        }

        \@media print { P.column7
        {
            font-style:  italic;
            font-weight: bold;
        }}

        p.column8
        {

        }

        p.column9
        {
            font-weight: bold;
        }

        p.column10
        {
            padding-top: 0;
        }

        em.quote10
        {
            /*
                #FF00FF Fuchsia;
                #0000FF Blue

                #87C0FF casual blue
                #87CAF0

                #A0FFFF Very light blue

                #809F69 = Forest Green , see /usr/lib/X11/rgb.txt

                background-color:

                color: #80871F ; Orange, short of

                # font-family: "Gill Sans", sans-serif;

                line-height: 0.9em;
                font-style:  italic;
                font-size:   0.8em;

                line-height: 0.9em;
                color: #008080;

                background-color: #F5F5F5;
                #809F69; forest green
                #F5F5F5; Pale grey
                #FFf098; pale green
                ##bfefff; #ffefff; LightBlue1

                background-color: #ffefff;

                .................
                #FFFCE7         Orange very light
                #FFE7BF         Orange dark
                #FFFFBF         Orange limon

             */

             /*
             #  See a nice page at
             #  http://www.cs.helsinki.fi/linux/
             #  http://www.cs.helsinki.fi/include/tktl.css
             #
             #  3-4 of these first fonts have almost identical look
             #  Browser will pick the one that is supported
             */

             font-family: lucida, lucida sans unicode, verdana, arial, "Trebuchet MS", helvetica, sans-serif;
             background-color: #eeeeff;
             font-size:   0.8em;
        }

        \@media print { em.quote10
        {
            font-style:  italic;
            line-height: 0.9em;
            font-size:   0.8em;
        }}

        p.column11
        {
            font-family: arial, verdana, helvetica, sans-serif;
            font-size: 0.9em;
            font-style: italic;
            color: Fuchsia;
        }

        /* /////////////////////////////////////////////// Format words */

        em.word
        {
            /* #809F69 Forest green */
            color: #80B06A;  /*Darker Forest green */
        }

        strong.word
        {

        }

        samp.word
        {
            color: #4C9CD4;
            font-weight: bold;
            font-family:    "Courier New", monospace;
            font-size:      0.85em;
        }

        span.super
        {
            /* superscripts */
            color: teal;
            vertical-align: super;
            font-family: Verdana, Arial, sans-serif;
            font-size: 0.8em;
        }

        span.word-ref
        {
            color: teal;
        }

        span.word-big
        {
            color: teal;
            font-size: 1.2em;
        }

        span.word-small
        {
            color: #CC66FF;
            font-family: Verdana, Arial, sans-serif;
            font-size: 0.7em;
        }

        /* /////////////////////////////////////////////// Format other */

        /* 7th column starting with double quote */

        span.quote7
        {
            /* color: Green; */
            /* font-style: italic; */
            font-family: Verdana;
            font-weigh: bold;
            font-size: 1em;
        }

        /* This appears in FRAME version: xxx-toc.html */

        div.toc
        {
            font-size: 0.8em;
        }

        /* This appears in picture: the acption text beneath */

        div.picture
        {
            font-style: italic;
        }

        /* This is the document info footer */

        em.footer
        {
            font-size: 0.9em;
        }
    ); # end of double quote qq();
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return CSS Style sheet and Java Script data.
#
#   USES GLOBAL
#
#       JAVA_CODE   See options.
#
#   INPUT VALUES
#
#       $type       What page we're creating? eg: "toc"
#
#   RETURN VALUES
#
#       $html
#
# ****************************************************************************

sub JavaScript (; $)
{
    my $id      = "$LIB.JavaScript";
    my ( $type )= @ARG;

    if ( defined $JAVA_CODE )
    {
        $JAVA_CODE;
    }
    else
    {
        my $css = CssData $type;

        #  won't work in Browsers....
        #  <style type="text/css"  media="screen, print">

        return qq(

    <style type="text/css">

$css

    </style>


    <!-- ...................................................... Java code -->

    <script type="text/javascript">

        function MakeVisual(obj)
        {
            obj.style.fontWeight = "italic";
        }

        function MakeNormal(obj)
        {
            obj.style.fontWeight = "normal";
        }

        function IgnoreErrors()
        {
            return true;
        }

        window.onerror = IgnoreErrors;

    </script>

        ); # end of qq()
    }

}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return Basic html start: doctype, head, body-start
#
#   INPUT PARAMETERS
#
#       $title
#       $baseFile   [optional] The html filename at $BASE_URL
#       $attrib     [optional] Attitional attributes
#       $rest       [optional] Rest HTML before </head>
#
#   USES GLOBAL
#
#       $BASE_URL
#
#   RETURN VALUES
#
#       $html
#
# ****************************************************************************

sub HtmlStartBasic ( % )
{

    #   [HTML 4.0/12.4] When present, the BASE element must appear in the
    #   HEAD section of an HTML document, before any element that refers to
    #   an external source. The path information specified by the BASE
    #   element only affects URIs in the document
    #   where the element appears.

    my $id = "$LIB.HtmlStartBasic";

    my %arg         = @ARG;
    my $title       = $arg{-title}  || '' ;
    my $baseFile    = $arg{-file}   || '' ;
    my $attrib      = $arg{-attrib} || '' ;
    my $rest        = $arg{-html}   || '' ;

    $debug  and  print "$id: INPUT title [$title] baseFile [$baseFile] "
                       , "attrib [$attrib] rest [$rest]\n";

    my $ret = HereQuote <<"........EOF";
        $HTML_HASH{doctype}

        $HTML_HASH{beg}

        <head>
            <title>
            $title
            </title>
........EOF

    $ret .= join ''
        , JavaScript()
        , Base($baseFile, $attrib)
        , $rest
        , "</head>\n\n\n"
        ;

    $ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Create <link> html tag
#
#       Advanced net browsers can use the included LINK tags.
#       http://www.htmlhelp.com/reference/wilbur/
#
#           REL="home": indicates the location of the homepage, or
#               starting page in this site.
#
#           REL="next"
#
#       Indicates the location of the next document in a series,
#       relative to the current document.
#
#           REL="previous"
#
#       Indicates the location of the previous document in a series,
#       relative to the current document.
#
#   NOTES
#
#       Note, 1997-10, you should not use this function because
#
#       a) netscape 3.0 doesn't obey LINK HREF
#       b) If you supply LINK and normal HREF; then lynx would show both
#          which is not a good thing.
#
#       Let's just conclude,t that LINK tag is not yet handled right
#       in browsers.
#
#   INPUT PARAMETERS
#
#       $type       the value of REL
#       $url        the value for HREF
#       $title      [optional] An advisory title for the linked resource.
#
#   RETURN VALUES
#
#       $string     html string
#
# **************************************************************************

sub MakeLinkHtml ($$$)
{
    my $id  = "$LIB.MakeLinkHtml";
    my( $type, $url , $title ) = @ARG;

    $title = $title ||  qq(TITLE="$title");

    qq(<link rel="$type" href="$url" $title>\n);
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Wrap text inkside comment
#
#   INPUT PARAMETERS
#
#       $text       Text to be put inside comment block
#
#   RETURN VALUES
#
#       $string     Html codes
#
# ****************************************************************************

sub MakeComment ($)
{

    my $id  = "$LIB.MakeComment";
    my $txt = shift;

    join ''
        , "\n\n<!--    "
        , "." x 70
        , "\n    $txt"
        , "\n    "
        , "." x 70
        , "\n-->\n\n"
        ;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Create Table of contents jump table to the html page
#
#   INPUT PARAMETERS
#
#       \@headingArrayRef   All heading in the text: 'heading', 'heading' ..
#       \%headingHashRef    'heading' -- 'NAME(html)' pairs
#       $doc                [optional] Url address pointing to the document
#       $frame              [optional] Aadd frame codes.
#       $file               [optional] Needed if frame is given.
#       $author             [optional]
#       $email              [optional]
#
#   RETURN VALUES
#
#       @array      Html codes for TOC
#
# ****************************************************************************

sub MakeToc ( % )
{
    my $id = "$LIB.MakeToc";

    my %arg             = @ARG;
    my $headingArrayRef = $arg{-headingListRef};
    my $headingHashRef  = $arg{-headingHashRef};
    my $doc             = $arg{-doc};
    my $frame           = $arg{-frame};
    my $file            = $arg{-file};
    my $author          = $arg{-author};
    my $email           = $arg{-email};

    local $ARG;
    my( $txt, $li,  $ul , $refname );
    my( @ret, $ref );
    my( $styleb, $stylee, $spc, $str ) = ("") x 4;
    my $br = $HTML_HASH{br};

    my $frameFrm = basename FileFrameNameMain();
    my $frameToc = basename FileFrameNameToc();
    my $frameTxt = basename FileFrameNameBody();

    if ( $debug   and  $frame )
    {
        warn "$id: arg_dir $ARG_DIR $frameFrm, $frameToc, $frameTxt\n";
    }

    if ( 0 )                # disabled now
    {
        $styleb = "<strong>";
        $stylee = "</strong>";
    }

    # ........................................................ start ...

    if ( $frame )
    {
        push @ret, <<"........EOF";
$HTML_HASH{doctype}

$HTML_HASH{beg}

<head>

    <title>
    Navigation
    </title>

........EOF

        push @ret,
            , MakeMetaTags( -author => $author, -email => $email)
            , qq(\n  <base target="body">\n)
            , JavaScript( "toc" )
            ;

        push @ret, Here <<"........EOF";

            </head>

            <body>
            <div class="TOC">

........EOF

        # ......................................... write frame file ...

        my @frame;

        my $head = HtmlStartBasic
            -title      => $TITLE
            , -file     => undef
            , -attrib   => qq(TARGET="body")
            , -html     => join '', MakeMetaTags(-author => $author,
                                                 -email  => $email)
            ;

        # push @frame, $head;

        #   Set default value

        my $frameSize  = qq(cols="25%,75%")         if $frame !~ /=/;
        my $attributes = qq(frameborder="0");    # Attributes

        push @frame, <<"........EOF";
$HTML_HASH{beg}

<!--  [HTML 4.0] 7.5.1 In frameset documents the FRAMESET element
      replaces the BODY element.
-->
<frameset $frameSize>

    <frame name="toc"
           id="toc"
           src="$frameToc"
           target="body"
           $attributes >

    <frame name="body"
           id="body"
           src="$frameTxt"
           $attributes >

</frameset>

</html>

........EOF

        WriteFile $ARG_DIR . $frameFrm, \@frame;
    }
    else
    {
        $doc    = "";
        my $toc = Language -toc;

        push @ret , MakeComment "TABLE OF CONTENT START";
        push @ret, <<"........EOF";

<div class="toc" id="toc">
<a name="toc" id="toc" class="name"></a>
<h1>
    $toc
    $doc
</h1>

........EOF
    }

    # .................................................. print items ...

    $ul     = 0;
    $frame  = basename FileFrameNameBody() if $frame;

    for ( @$headingArrayRef )
    {
        $refname = $$headingHashRef{ $ARG };

#        print "\n" if not /^\s+/;
        $spc = "";
        $spc = $1 if /^(\s+)/;
        $txt = $1 if /^\s*(.*)\s*$/;

        $li = $str = "";

        if ( /^ +[A-Z0-9]/ )
        {
            $str =  "\n<ul>\n"  if $ul == 0;
            $li  = "\t<li>";
            $ul++;
        }
        else
        {
            $str = "</ul>\n"  if $ul != 0;
            $ul = 0;
        }

        $ref = "#${refname}";
        $ref = $frame . $ref   if defined $frame;

        $str .= HereQuote <<"........EOF";
            $spc$styleb
            $li
            <a href="$ref" class="toc">
                $txt
            </a>
            $stylee$br

........EOF

        push @ret, $str;
    }

    #  The closing table element.

    push @ret, "</ul>\n\n";

    # .......................................................... end ...

    if( $frame )
    {
        push @ret, Here <<"........EOF";
            </div>
            </body>
            </html>
........EOF
    }
    else
    {
        push @ret
            , "</div>\n"
            , MakeComment "TABLE OF CONTENT END"
            ;
    }

    $debug  and  PrintArray "$id", \@ret;


    @ret;
}

# }}}
# {{{ URL Link

# ****************************************************************************
#
#   DESCRIPTION
#
#       Link cache actions. Read, Write or check against the cache.
#
#   INPUT PARAMETERS
#
#       -action     This can be -read, -write, -exist or -add.
#                   Action -read is special: it enables the cache
#                   immediately. Otherwise if -read has not been called
#                   all the other actions are no-op.
#
#                   If argument is -write, the -arg is ignored, because a
#                   write file request is only action.
#
#       -arg        [optional] Parameter for actions.
#       -code       [optional] HTTP code to acctach with the URL (-arg).
#                   Used with -add option.
#
#
#   RETURN VALUES
#
#                   If action is -check, then URL link is checked
#                   against the cache. A true value is returned if the
#                   link is already there.
#
#                   If -read, then a true value indicates that the
#                   cache file could be opened and read.
#
# ****************************************************************************

{
    my $staticActive = 0;
    my $staticFile;
    my %staticLinkCache;

sub LinkCache ( % )
{
    my $id    = "$LIB.LinkCache";

    my %arg     = @ARG;
    local $ARG  = $arg{-action} || "" ;
    my $arg     = $arg{-arg}    || "" ;
    my $code    = $arg{-code}   || 200;

    my $ret = 1;

    if ( $debug > 1 )
    {
        print "$id: action [$ARG] arg [$arg] "
            , "act [$staticActive] code [$code]\n";
    }

    if ( /-read/ )
    {
        $staticActive = 1;      # start using cache
        $staticFile   = $arg;

        local *FILE;

        #   It is not an serious error if we can't open the cache.
        #   This means, that user has deleted cache file and forcing
        #   a full scan of every link.

        unless ( open FILE, "<$arg" )
        {
            $verb > 1  and  warn "$id: Cannot open $arg $ERRNO";
            $ret = 0;
        }
        else
        {
            $verb and  print "$id: reading [$arg]\n";

            while ( <FILE> )
            {
                #   Filter out empty lines and extra spaces

                s/^\s+//; s/\s+$//;

                $staticLinkCache{ $ARG } = $HTTP_CODE_OK if $ARG;

                $debug > 2 and  print "$id: -read => $ARG\n";
            }

            close FILE;
        }
    }
    elsif  ( $staticActive  and  /-write/ )
    {
        $arg = $staticFile;         # Same as used in open

        $verb  and  print "$id: writing [$arg]\n";

        my $stat = open my $FILE, "> $arg";

        unless ( $stat )
        {
            not $QUIET  and  warn "$id: Cannot write $arg $ERRNO";
            $ret = 0;
        }
        else
        {
            binmode $FILE;

            # PrintHash "$id",  \%staticLinkCache;

            while ( my($url, $ccode) = each %staticLinkCache )
            {
                if ( $ccode != $HTTP_CODE_OK )
                {
                    $debug > 2 and  print "$id: Ignored $url $ccode\n";
                    next;
                }

                $debug > 2  and  print "$id: write => $url\n";

                if ( $url )
                {
                    print $FILE $url, "\n";
                }
            }

            close $FILE;
        }
    }
    elsif ( /-add/ )
    {
        $staticLinkCache{ $arg } = $code;
        $ret = 1;

        $debug > 1  and  print "$id: added ok\n";
    }
    elsif ( /-exist/ )
    {
        $ret = exists $staticLinkCache{$arg}
               ? $staticLinkCache{$arg}
               : 0;

        $verb > 1  and  print "$id: exist status [$ret]\n";
    }
    elsif ( $staticActive )
    {
        die "$id: Unknown action [$ARG] arg [$arg]";
    }

    $ret;
}}

# *************************************************************** &link ******
#
#   DESCRIPTION
#
#       Update status code in link hash
#
#   INPUT PARAMETERS
#
#       $url    string containing the link or pure URL link
#
#   RETURN VALUES
#
#               Global %LINK_HASH is updated too with key 'link' -- 'response'
#
# ****************************************************************************

sub LinkHash (%)
{
    my $id = "$LIB.LinkHash";

    my %arg     = @ARG;
    my $url     = $arg{-url};
    my $error   = $arg{-error};
    my $text    = $arg{-text};

    $LINK_HASH{ $url } = $error;

    #  There is new error code, record it.

    if ( not defined $LINK_HASH_CODE{ $error }  )
    {
        $LINK_HASH_CODE{ $error } = $text;
    }
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Check if link is valid
#
#   INPUT PARAMETERS
#
#       $str    string containing URL
#
#   RETURN VALUES
#
#       $nbr    Error code.
#       $txt    Error text
#
# ****************************************************************************

sub LinkCheckLwp ($)
{
    my $id = "$LIB.LinkCheckLwp";
    my ( $url ) = @ARG;

    $debug  and  print "$id: processing... $url\n";

    my $code = LinkCache -action => '-exist', -arg => $url;

    if ( $code == $HTTP_CODE_OK )
    {
        #   Found from cache. Last check gave OK to this link
        $debug > 1 and  print "$id: Return; cached value $code $url\n";
        return $code, "local-cache";
    }

    #  Note:  'HEAD' request doesn't actually download the
    #  whole document. 'GET' would.
    #
    #   Code 200  is "OK" response

    my $ua      = new LWP::UserAgent;
    my $request = new HTTP::Request( 'HEAD', $url );
    my $obj     = $ua->request( $request );
    my $ok      = $obj->is_success;
    my $status  = $ok;
    my $txt     = $obj->message;

    $debug  and
        printf "$id: HEAD response [$ok] code [%d] msg [%s]\n"
               , $obj->code
               , $obj->message
               ;

    LinkCache -action => '-add'
            , -arg    => $url
            , -code   => $obj->code
            ;

    #  GET request is disabled because it would call 2 time on
    #  fialure. Trust HEAD all the way.

    unless ( 0 and $status != $HTTP_CODE_OK  )
    {
        #  Hm,
        #  HEAD is not the total answer because there are still servers
        #  that do not understand it.  If the HEAD fails, revert to GET.  HEAD
        #  can only tell you that a URL has something behind it. It can't tell
        #  you that it doesn't, necessarily.

        my $ua2      = new LWP::UserAgent;
        my $request2 = new HTTP::Request( 'GET', $url );
        my $obj2     = $ua2->request( $request2 );
        $status      = $obj2->code;
        $txt         = $obj2->message;

        $debug  and
            printf "$id: GET response [$ok] code [%d] [%s]\n"
                 , $obj2->code
                 , $txt
                 ;
    }

    unless ( $status != $HTTP_CODE_OK )
    {
        LinkHash -url => $url, -error => $status, -txt => $txt;
    }

    $status, $txt;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Check if link is valid
#
#   INPUT PARAMETERS
#
#       $str    string containing the link or pure URL link
#
#   RETURN VALUES
#
#       nbr     Error code.
#               Global %LINK_HASH is updated too with key 'link' -- 'response'
#
# ****************************************************************************

sub LinkCheckExternal ( % )
{
    my $id  = "$LIB.LinkCheckExternal";

    my %arg = @ARG;
    my $url = $arg{-url};

    $debug  and  print "$id: Checking... $url\n";

    my $regexp = 'example\.(com|org|net|info|biz)'
                 . '|http://(localhost|127\.(0.0.)?1'
                 . '|foo|bar|baz|quuz)\.'
                 ;

    my($ret, $txt) = (0, "");

    if ( $url =~ /$regexp/o )
    {
        $verb  and  print "$id: Link [$url] excluded by regexp [$regexp]\n";
    }
    elsif ( $MODULE_LWP_OK )
    {
        ($ret, $txt) = LinkCheckLwp $url;
    }

    $debug  and  warn "$id: RET [$ret] URL [$url] TEXT [$txt]\n";

    $ret, $txt;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       convert html into ascii by just stripping anything between
#       < and > written 1996-04-21 by Michael Smith for WebGlimpse
#
#   INPUT PARAMETERS
#
#       \@arrayRef    text lines
#
#   RETURN VALUES
#
#       @
#
# ****************************************************************************

sub Html2txt ($)
{
    my $id         = "$LIB.Html2txt";
    my $arrayRef   = shift;

    unless ( defined $arrayRef )
    {
        warn "$id: [ERROR] \$arrayRef is not defined";
        return;
    }

    my ( @ret, $carry, $comment );

    for ( @$arrayRef )
    {
        if ( 0 )        # enable/disable comment stripping
        {
            $comment = 1 if /<!/;
            $comment = 0 if /<!.*>/;
            $comment = 0 if /-->/;

            next if $comment;
        }

        if ( $carry )
        {
            #   remove all until the first >

            next if not s/[^>]*>// ;

            #   if we didn't do next, it succeeded -- reset carry

            $carry = 0;
        }

        while( s/<[^>]*>//g ) { }

        if( s/<.*$// )
        {
            $carry = 1;
        }

        $ARG = XlatHtml2tag $ARG;

        push @ret,  $ARG;
    }

    $debug  and  print "$id: RET => [[[@ret]]]\n";

    @ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Read external links.
#       http://search.cpan.org/author/PODMASTER/HTML-LinkExtractor-0.07/LinkExtractor.pm
#   INPUT PARAMETERS
#
#       %arg     Options
#
#   RETURN VALUES
#
#       %       all found links  'line nbr' => link
#
#
# ****************************************************************************

sub ReadLinksLinkExtractor (%)
{
    my $id          = "$LIB.ReadLinksLinkExtractor";
    my %arg         = @ARG ;
    my $file        = $arg{-file};      # also URL
    my $arrayRef    = $arg{-array};

    unless ( defined $arrayRef )
    {
        warn "$id: [ERROR] \$arrayRef is not defined";
        return;
    }

    local $ARG      = join '', @$arrayRef;
    my ( @list, $base );

    $base = $file   if   $file =~ m,http://,i;

    local *callback = sub
    {
        my( $tag, %links) = @ARG;

        #   Only look at "A" HREF links

        if ( $tag eq "a" )
        {
            while ( my($key, $ref) = each %links )
            {
                #  Reference to URI::URL object
                my $url = $ref->as_string();

                push @list, $url;
            }
        }
    };

    my $parser = HTML::LinkExtractor->new( \&callback, $base);

    # $debug > 2  and  print "$id: Calling parse() => $ARG";

    $parser->parse( $ARG );

    #       Add fake line numbers, we can't get those from LinkExtractor

    my %ret;
    my $i = 1;

    for my $link ( @list )
    {
        $ret{$i++} = $link;
    }

    %ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Read external links. Any link that is started with (-) is skipped, like
#       -http://skip.this.net/
#
#   INPUT PARAMETERS (hash)
#
#       -array  \@array, list of lines.
#       -file   local file name or remote URL.
#
#   RETURN VALUES
#
#       %       all found links  in format NN=countXX => link, where
#               NN is the line number and XX is the the Nth link in the same
#               line.
#
# ****************************************************************************

sub ReadLinksBasic (%)
{
    my $id          = "$LIB.ReadLinksBasic";

    my %arg         = @ARG ;
    my $file        = $arg{-file};
    my $arrayRef    = $arg{-array};

    unless ( defined $arrayRef )
    {
        warn "$id: [ERROR] \$arrayRef is not defined";
        return;
    }

    local $ARG      = join '', @$arrayRef;      # Make on big line
    my ($url, %ret, $char, $link, $tmp);

    #   ftp links cannot be checked like HTTP links. It's too slow.
    #   Allow http://site:PORT/page.html

    my $base = '';
    my $root = '';

    if ( $file =~ m,^\s*(http://[^/\s]+), )
    {
        $base = $1 . '/'; # Add trailing slash
        $root = $base;

        $debug  and  print "$id: ROOT $root BASE $base\n";
    }

    my $tag    = '<\s*(?:A\s+HREF|IMG\s+SRC|LINK[^<>=]+HREF)\s*';
    my $urlset = '[^][<>\"\s]';
    my $lastch = '[^][(){}<>\"\':;.,\s]';
    my $quote  = '[\"\']';

    while
    (
        m
        {
            (.?)
            (
                # http://URL:PORT

                http://[-A-Za-z.\d]+(?::\d+)?

                #   the directory part is optional
                #   Start with X ... until X is the last character

                $urlset*$lastch

                |

                $tag=\s*$quote?[^<>\"'\s]+

                #  (') Dummy comment to fix Emacs font loack for
                #  quotation mark from previous line

            )
        }gmoix
    )
    {
        $char = $1;
        $link = $2;
        $tmp  = $PREMATCH;

        $debug > 4  and  print "$id: raw link   [$char] [$link]\n";

        #      Fix mismatches http://example.org/links.html&gt
        #      only GET parameters can have '?': this.php?arg=1&more=2

        if ( $link !~ /[?]/  and  $link =~  /^(.+)&/ )
        {
            $link = $1;
            $debug > 4  and  print "$id: fixed link [$link]\n";
        }

        if ( $link =~ /mailto:/ )
        {
            $link = '';
        }

        if ( $link =~ m,(?:HREF|SRC)\s*=\s*$quote?(.+),oi )
        {
            #   (') Dummy comment to fix Emacs font lock quotation mark
            #   from previous line

            $link = $1;

            $debug > 2  and  print "$id: LINK  $link\n";

            #  Not an external http:// reference, so it's local link

            if ( $base  and  $link !~ m,//, )
            {
                my $glue = $base;

                $link =~ m,^/,   and  $glue = $root;
                $link = "$glue$link";
            }
        }

        $link =~ s/\s+$//;

        $debug > 2   and  print "$id: AFTER $link\n";

        if ( $char eq '-' )          # Ignore -http://this.is/example.html
        {
            not $QUIET  and  warn "$id: ignored MINUS url: $ARG\n";
            next;
        }

        #   Do not check the "tar.gz" links. or "url?args" cgi calls

        if ( $link =~ m,\.(gz|tgz|Z|bz2|rar)$|\?, )
        {
            not $QUIET  and  warn "$id: ignored complex url: $ARG\n";

            next if m,\?,;                          # forget cgi programs

            # but try to verify at least directory

            $link =~ s,(.*/),$1,;
        }

        if ( $link ne '' )
        {
            #   What is the line number so far before match?
            my $i = 0;

            $i++ while ( $tmp =~ /\n/g );

            #  There can be many links at the the same line.
            #  Like if page is generated with a tool, which outputs whole
            #  page as single line.

            my $count = 0;
            my $name;

            while ( exists $ret{ $name = sprintf "$i=count%03d", $count } )
            {
                $count++;
            }

            $debug  and  print "$id: ADDED $id $link\n";
            $ret{ $name } = $link ;
        }
    }

    if ( $verb > 1  and  not keys %ret )
    {
        print "$id:  WARNING No links found\n";
    }

    %ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Read external links. Any link that is started with (-) is skipped, like
#       -http://skip.this.net/
#
#   INPUT PARAMETERS
#
#       -array      \@lines, content of web page.
#       -file       local file name or remote URL
#
#   RETURN VALUES
#
#       %           all found links
#
# ****************************************************************************

sub ReadLinksMain (%)
{
    my $id          = "$LIB.ReadLinks";
    my %arg         = @ARG ;

    if ( $debug )
    {
        print "$id: file => " , $arg{-file};

        $debug > 6 and print
            " content => CONTENT_START\n"
            , @{ $arg{-array} }
            , "\n$id: CONTENT_END"
            ;

        print "\n";
    }

    $MODULE_LINKEXTRACTOR_OK = 0;  #todo: 0.07 does not work

    $verb  and  print "$id: Parsing links\n";

    my %hash;

    if ( $MODULE_LINKEXTRACTOR_OK )
    {
        %hash = ReadLinksLinkExtractor %arg;
    }
    else
    {
        %hash = ReadLinksBasic %arg;
    }

    $debug > 4  and  PrintHash $id, \%hash;

    %hash;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Check all links in a file
#
#   INPUT PARAMETERS (hash)
#
#       -file       local disk filename or remote url.
#       -array      \@lines, content of the file
#       -cache      Enable Link cache
#       -oneline    [Not used]
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub LinkCheckMain ( % )
{
    my $id   = "$LIB.LinkCheck";

    my %arg         = @ARG ;
    my $file        = $arg{-file};
    my $arrayRef    = $arg{-array};
    my $oneLine     = $arg{-oneline};

    if  ( not defined $arrayRef  or  not @$arrayRef )
    {
        warn "$id: WARNING [$file] is empty\n";
        return;
    }

    my %link = ReadLinksMain -array => $arrayRef
                           , -file  => $file;

    $debug  and  PrintHash "$id: LINKS", \%link;
    $verb   and  print "$id: Validating links.\n";

    local $ARG;

    for ( sort {$a <=> $b} keys %link  )
    {
        my ($i) = $ARG =~ /^(\d+)/;
        my $lnk = $link{ $ARG };

        my($status, $err) = LinkCheckExternal -url => $lnk;

        not $QUIET   and print  "$file:$i:$lnk";

        my $text = "";

        if ( $err  and  $LINK_CHECK_ERR_TEXT_ONE_LINE )
        {
            ($text = $err) =~ s/\n/./;
        }

        if ( not $QUIET )
        {
            print " $status $text\n";   # this print() is continuation...
        }
        elsif ( $status != 0  and  $status != $HTTP_CODE_OK )
        {
            printf "$file:$i:%-4d $lnk $text\n", $status;
        }
    }
}

# }}}
# {{{ Is, testing

# **************************************************************** &test *****
#
#   DESCRIPTION
#
#       Check if TEXT contains no data. Empty, only whitespaces
#       or "none" word is considered empty text.
#
#   INPUT PARAMETERS
#
#       $text   string
#
#   RETURN VALUES
#
#        0,1
#
# ****************************************************************************

sub IsEmptyText ($)
{

    my $id   = "$LIB.IsEmptyText";
    my $text = shift;

    if  ( not defined $text
          or  $text eq ''
          or  $text =~ /^\s+$|[Nn][Oo][Nn][Ee]$/
        )
    {
        return 1;
    }

    0;
}

# **************************************************************** &test *****
#
#   DESCRIPTION
#
#       If LINE is heading, return level of header.
#       Heading starts at column 0 or 4 and the first leffter must be capital.
#
#   INPUT PARAMETERS
#
#       $line
#
#   RETURN VALUES
#
#        1..2   Level of heading
#        0      Was not a heading
#
# ****************************************************************************

sub IsHeading ($)
{
    my $id   = "$LIB.IsHeading";
    my $line = shift;
    my $ret  = 0;

    $ret = 1    if  $line =~ /^([\d.]+ )?[[:upper:]]/;
    $ret = 2    if  $line =~ /^ {4}([\d.]+ )?[[:upper:]]/;

    $debug > 2  and  warn "$id: [$line] RET $ret";

    $ret;
}

# **************************************************************** &test *****
#
#   DESCRIPTION
#
#       If LINE is bullet, return type of bullet
#
#   INPUT PARAMETERS
#
#       $line       line
#       $textRef    [returned] the bullet text
#
#   RETURN VALUES
#
#        $BULLET_TYPE_NUMBERED    constants
#        $Bulletnormal
#
# ****************************************************************************

sub IsBullet ($$)
{
    my $id = "$LIB.IsBullet";
    my( $line, $textRef ) = @ARG;

    my $type    = 0;

    #   Bullet can starters:
    #
    #   .   Numbered list
    #   .   Numbered list
    #
    #   o   Regular bullet
    #   o   Regular bullet
    #
    #   *   Regular bullet
    #   *   Regular bullet

    if ( $line =~ /^ {8}([*o.]) {3}(.+)/  )
    {
        $$textRef = $2;     # fill return value

        if ( $1 eq "o"  or   $1 eq "*" )
        {
            $debug and warn "$id: BULLET_TYPE_NORMAL >>$2\n";
            $type = $BULLET_TYPE_NORMAL;
        }
        elsif ( $1 eq "." )
        {
            $debug and warn "$id: BULLET_TYPE_NUMBERED >>$2\n";
            $type = $BULLET_TYPE_NUMBERED;
        }
    }

    $type;
}

# }}}
# {{{ start, end

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return HTML string containing meta tags.
#
#   INPUT PARAMETERS
#
#       $author
#       $email
#       $kwd        [optional]
#       $desc       [optional]
#
#   RETURN VALUES
#
#       @html
#
# ****************************************************************************

sub MakeMetaTags ( % )
{
    my $id = "$LIB.MakeMetaTags";

    my %arg     = @ARG;
    my $author  = $arg{-author}     || '' ;
    my $email   = $arg{-email}      || '' ;
    my $kwd     = $arg{-keywords}   || '' ;
    my $desc    = $arg{-description}|| '' ;

    #   META tags provide "meta information" about the document.
    #
    #   [wilbur] You can use either HTTP-EQUIV or NAME to name the
    #   meta-information, but CONTENT must be used in both cases. By using
    #   HTTP-EQUIV, a server should use the name indicated as a header,
    #   with the specified CONTENT as its value.

    my @ret;

    my $META  = "meta http-equiv";
    my $METAN = "meta name";

    # ............................................. meta information ...

    #   META must be inside HEAD block

    push @ret, MakeComment "META TAGS (FOR SEARCH ENGINES)";

    if ( $kwd =~ /\S+/ and $kwd !~ /^\S+$/ )
    {
        #   "keywords" [according to Wilbur]
        #   Provides keywords for search engines such as Infoseek or Alta
        #   Vista. These are added to the keywords found in the document
        #   itself. If you insert a keyword more than seven times here,
        #   the whole tag will be ignored!

        if (  $kwd !~ /,/  )
        {
            $kwd = join ","  ,   split ' ', $kwd;

            warn "$id: META KEYWORDS must have commas (fixed): ",
                " [$kwd]";
        }

        push @ret, qq(  <$META="keywords"\n\tCONTENT="$kwd">\n\n);
    }

    if ( defined $desc )
    {
        length($desc) > 1000
            and warn "$id: META DESC over 1000 characters";

        push @ret, qq(  <$META="description"\n\tcontent="$desc">\n\n);
    }

    # ................................................. general meta ...

    my $charset = qq(<$META="Content-Type" content="text/html; charset=utf-8">\n);

    push @ret, $charset;

    push @ret, qq(  <$META="Expires" )
               . qq(content=") .  GetExpiryDate() . qq(">\n\n)
               ;

    if ( defined $author  and  $author )
    {
        $author = qq(  <$META="Author"\n\tcontent="$author">\n\n);
    }

    if ( defined $email  and $email )
    {
        $email = qq(  <$META="Made"\n\tcontent="mailto:$email">\n\n);

    }

    my $gen = qq(  <$METAN="Generator"\n)
            . qq(\tcontent=")                                       #font "
            . GetDate()
            . qq( Perl program $PROGNAME v$VERSION $URL)
            . qq(">\n)                                              #font "
            ;

    push @ret, "$author\n", "$email\n", "$gen\n";

    @ret;

}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Print start of html document
#
#   INPUT PARAMETERS
#
#       $doc
#       $author         Author of the document
#       $title          Title of the document, appears in Browser Frame
#       $base           URL to this localtion of the document.
#       $butt           Url Button to point to "Top"
#       $butp           Url Button to point to "Previous"
#       $butn           Url Button to point to "next"
#       $metaDesc       [optional]
#       $metaKeywords   [optional]
#       $bodyAttr       [optional] Attributes to attach to BODY tag,
#                       e.g. <body lang=en> when value would be "LANG=en".
#       $email          [optional]
#
#   RETURN VALUES
#
#       @   list of html lines
#
# ****************************************************************************

sub PrintStart ( % )
{
    my $id = "$LIB.PrintStart";

    my %arg         = @ARG;
    my $doc         = $arg{-doc}                || '';
    my $author      = $arg{-author}             || '';
    my $title       = $arg{-title}              || '';
    my $base        = $arg{-base}               || '';
    my $butt        = $arg{-butt}               || '';
    my $butn        = $arg{-butn}               || '';
    my $butp        = $arg{-butp}               || '';
    my $metaDesc    = $arg{-metaDescription}    || '';
    my $metaKeywords= $arg{-metaKeywords}       || '';
    my $bodyAttr    = $arg{-bodyAttr}           || '';
    my $email       = $arg{-email}              || '';

    $debug and  warn << "EOF";
$id: INPUT
    my \%arg       = @ARG;
    my doc         = $arg{-doc}
    my author      = $arg{-author}
    my title       = $arg{-title}
    my base        = $arg{-base}
    my butt        = $arg{-butt}
    my butn        = $arg{-butn}
    my butp        = $arg{-butp}
    my metaDesc    = $arg{-metaDescription}
    my metaKeywords= $arg{-metaKeywords}
    my bodyAttr    = $arg{-bodyAttr}
    my email       = $arg{-email}
EOF

    my( $str , $tmp ) = ( "", "");
    my @ret  = ();
    my $link = 0;           # Flag; Do we add LINK AHREF ?
    my $tab  = "  ";

    $title = "No title"     if $title eq '';

    # ................................................ start of html ...
    # 1998-08 Note: Microsoft Internet Explorer can't show the html page
    # if the comment '<!--' is placed before comment <html> tag.
    # Netscape will show .html ok. By moving the comment after <html>
    # IE is able to read the page.

    push @ret, HereQuote <<"........EOF";
        $HTML_HASH{doctype}

        $HTML_HASH{beg}

        <!--
                Note: the LINK tags are used by advanced browsers.
        -->

........EOF

    # ... ... ... ... ... ... ... ... ... ... ... ... ... ... .. push ...

    $base = Base( basename FileFrameName "");
    $base = Base( basename FileFrameNameBody() ) if $FRAME;

    push @ret, HereQuote <<"........EOF";
        <head>

        <title>
        $title
        </title>

        $base

........EOF

    push @ret, MakeMetaTags(
        -author         => $author
        , -email        => $email
        , -keywords     => $metaKeywords
        , -description  => $metaDesc
        );

    # ....................................................... button ...

    my $attr;

    # [wc3 html 4.0 / 6.16 Frame target names]
    #  _top
    #   The user agent should load the document into the full, original window
    #   (thus cancelling all other frames). This value is equivalent to _self
    #   if the current frame has no parent.

    $attr = qq( target="_top" class="btn" );

    push @ret, MakeComment "BUTTON DEFINITION START";

    if ( not IsEmptyText $butp )
    {
        $tmp = "Previous document";

        $link and push @ret, $tab , MakeLinkHtml("previous","$butp", $tmp);

        push @ret
            , $tab
            , MakeUrlRef( $butp, "[Previous]", $attr)
            , "\n";
    }

    if ( not IsEmptyText $butt )
    {
        $tmp = "The homepage of site";

        $link and push @ret, $tab , MakeLinkHtml("home","$butt", $tmp);

        push @ret
            , $tab
            , MakeUrlRef( $butt, "[home]", $attr)
            , "\n";
    }

    if ( not IsEmptyText $butn )
    {
        $tmp = "Next document";

        $link and push @ret, $tab . MakeLinkHtml("next","$butt", $tmp);

        push @ret
            , $tab
            , MakeUrlRef( $butn, "[Next]", $attr)
            , "\n";
    }

    push @ret
        , JavaScript()
        , "</head>\n\n"
        , "<body $bodyAttr>\n";

    $debug and  PrintArray "$id", \@ret;

    @ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Print end of html (quiet)
#
#   INPUT PARAMETERS
#
#       none
#
#   RETURN VALUES
#
#       $html
#
# ****************************************************************************

sub PrintEndQuiet ()
{
    my $id  = "$LIB.PrintEndQuiet";

    $debug  and  print "$id\n";

    join ''
        , MakeComment "DOCUMENT END BLOCK"
        , "<!--\n\n\n"
        , "-->\n"
        , "</body>\n"
        , "</html>\n"
        ;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Print end of html (simple)
#
#   INPUT PARAMETERS
#
#       $doc        The document filename, defaults to "document" if empty
#
#   RETURN VALUES
#
#       $html
#
# ****************************************************************************

sub PrintEndSimple ($;$)
{
    my $id  = "$LIB.PrintEndSimple";
    my ($doc, $email) = @ARG;

    $debug  and  print "$id: doc [$doc] [$email]\n";

    my $date = GetDate();

    if ( defined $OPT_EMAIL  and  $OPT_EMAIL )
    {
        $email = qq(Contact: &lt;<a href="mailto:$email">)
                 . qq($email</a>&gt;$HTML_HASH{br}\n)
    }

    join ''
        , MakeComment "DOCUMENT END BLOCK"
        , "<!--\n\n\n"
        , "-->\n"
        , "$HTML_HASH{hr}\n\n"
        , qq(<em    class="footer">)
        , $email
        , qq(Html date: $date$HTML_HASH{br}\n)
        , "\n"
        , "</em>\n\n"
        , "</body>\n"
        , "</html>\n"
        ;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Print end of html
#
#   INPUT PARAMETERS
#
#       $doc        The document filename, defaults to "document" if empty
#       $author     Author of the document
#       $url        Url location of the file
#       $file       [optional] The disclaimer text file
#       $email      Email contact address. Without <>
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub PrintEnd ( % )
{
    my  $id  = "$LIB.PrintEnd";

    my %arg     = @ARG;
    my $doc     = $arg{-doc}        ||  "document" ;
    my $author  = $arg{-author}     ||  "";
    my $url     = $arg{-url}        ||  "";
    my $file    = $arg{-file};
    my $email   = $arg{-email}      ||  "";


    $debug and  warn << "EOF";
$id: INPUT
    \%arg     = @ARG;
    doc     = $arg{-doc}
    author  = $arg{-author}
    url     = $arg{-url}
    file    = $arg{-file};
    email   = $arg{-email}
EOF

    my( @ret, $str );

    my $date = GetDate();
    my $year = GetDateYear();
    my ($br, $hr, $pbeg, $pend) = @HTML_HASH{qw(br hr pbeg pend)};

    # ................................................... disclaimer ...
    #   Set default value first

    # #todo: Change license

    my $disc =  Here <<"........EOF";

        $pbeg
        Copyright &copy; $year by $author. This material may be
        distributed subject to the terms and conditions set forth
        in the Creative commons Attribution-ShareAlike License.
        See http://creativecommons.org/
        $pend

........EOF

    if ( defined $file )              # Read the disclaimer from separate file.
    {
        local *F;
        open F, $file       or die "$id: Can't open [$file] $ERRNO";
        binmode F;

        $disc = join '', <F>;
        close F;
    }

    # ....................................................... footer ...

    push @ret, MakeComment "DOCUMENT END BLOCK";

    $author ne '' and $author = qq(Document author: $author$br);
    $url    ne '' and $url    = qq(Url: <a href="$url">$url</a>$br);
    $email  ne '' and $email  =
                  qq(Contact: &lt;<a href="mailto:$email">)
                  . qq($email</a>&gt;$br);

    $author eq '' and $disc = '';

    push @ret, Here <<"........EOF";

        $hr

        <em    class="footer">
        $disc

        $pbeg
        This file has been automatically generated from plain text file
        with
        <a href="$URL">$PROGNAME</a>
        $br
        $pend

        $author
        $url
        $email
        Last updated: $date$br

        </em    class="footer">

        </body>
        </html>
........EOF

    # ................................................. return value ...

    @ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Print whole generated html body with header and footer.
#
#   INPUT PARAMETERS
#
#       The Global variables that have been defined at the start
#       are used here
#
#       $arrayRef   Content of the body already in html
#       $lines
#       $file
#       $type
#
#   RETURN VALUES
#
#       \@      Whole html
#
# ****************************************************************************

sub PrintHtmlDoc ( % )
{
    my $id = "$LIB.PrintHtmlDoc";

    my %arg         = @ARG;
    my $arrayRef    = $arg{-arrayRef};
    my $lines       = $arg{-lines};
    my $file        = $arg{-file};
    my $type        = $arg{-type};
    my $title       = $arg{-title};
    my $author      = $arg{-author};
    my $email       = $arg{-email};
    my $doc         = $arg{-doc};
    my $keywords    = $arg{-metakeywords};
    my $description = $arg{-metadescription};

    $debug  and  warn << "EOF";
$id: INPUT
    \%arg         = @ARG;
    arrayRef    = $arg{-arrayRef};
    lines       = $arg{-lines};
    file        = $arg{-file};
    type        = $arg{-type};
    title       = $arg{-title};
    author      = $arg{-author};
    email       = $arg{-email};
    doc         = $arg{-doc};
    keywords    = $arg{-metakeywords};
    description = $arg{-metadescription};
EOF

    my $str;
    my $base = $BASE;                   # With filename (single file)
    $base    = $BASE_URL if $FRAME;     # directory

    my @ret = PrintStart
                -doc        => $doc
                , -author   => $author
                , -title    => $title
                , -base     => $base
                , -butt     => $BUT_TOP
                , -butp     => $BUT_PREV
                , -butn     => $BUT_NEXT
                , -metaDesc => $description
                , -metaKeywords => $keywords
                , -bodyAttr => $HTML_BODY_ATTRIBUTES
                , -email    => $email
                ;

    unless ( $AS_IS )
    {
        my @toc = MakeToc
            -headingListRef     => \@HEADING_ARRAY
            , -headingHashRef   => \%HEADING_HASH
            , -doc              => $DOC
            , -frame            => $FRAME
            , -file             => $file
            , -author           => $AUTHOR
            , -email            => $OPT_EMAIL
            ;

        if ( $FRAME )
        {
            WriteFile FileFrameNameToc(), \@toc;
        }
        else
        {
            push @ret, @toc;
        }
    }

    push @ret, @$arrayRef if defined $arrayRef;

    $debug  and  print "$id: output type [$type]\n";

    if ( $type eq $OUTPUT_TYPE_SIMPLE )
    {
        push @ret, PrintEndSimple $DOC, $OPT_EMAIL;
    }
    elsif ( $type eq $OUTPUT_TYPE_QUIET )
    {
        push @ret, PrintEndQuiet();
    }
    else
    {
        push @ret, PrintEnd -doc => $DOC
                    , -author    => $AUTHOR,
                    , -url       => $DOC_URL
                    , -file      => $DISCLAIMER_FILE
                    , -email     => $OPT_EMAIL
                    ;
    }

    \@ret;
}

# }}}
# {{{ misc

# ****************************************************************************
#
#   DESCRIPTION
#
#       Delete section "Table of contents" from text file
#
#   INPUT PARAMETERS
#
#       \@arrayRef  whole text
#
#   RETURN VALUES
#
#       @           modified text
#
# ****************************************************************************

sub KillToc ($)
{
    my $id       = "$LIB.KillToc";
    my $arrayRef = shift;

    unless ( defined $arrayRef )
    {
        warn "$id: [ERROR] \$arrayRef is not defined";
        return;
    }

    my( @ret, $flag );

    for ( @$arrayRef )
    {
        $flag = 1 if /^Table\s+of\s+contents\s*$/i;

        if ( $flag )
        {
            #  save next header

            next if /^Table/;

            if ( /^[A-Z0-9]/ )
            {
                $flag = 0;
            }
            else
            {
                next;
            }
        }
        push @ret, $ARG;
    }

    @ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Read 4 first words and make heading name. Any numbering or
#       special marks are removed. The result is all lowercase.
#
#   INPUT PARAMETERS
#
#       $lien       Heading string
#
#   RETURN VALUES
#
#       $           Abbreviated name. Suitable eg for #NAME tag.
#
# ****************************************************************************

{
    #   Static variables. Only used once to make constructiong regexp easier

    my $w           = "[.\\w]+";        # A word.
    my $ws          = "$w\\s+";         # A word and A space

sub MakeHeadingName ($)
{
    my $id         = "$LIB.MakeHeadingName";
    local ( $ARG ) = @ARG;

    $debug  > 2 and   print "$id: -1- $ARG\n";

    s,&auml;,a,g;       # 228 Finnish a
    s,&Auml;,A,g ;      # 228 Finnish A
    s,&ouml;,o,g;       # 246 Finnish o
    s,&Ouml;,O,g;       # 246 Finnish O
    s,&aring;,a,g;      # 229 Swedish a
    s,&Aring;,A,g;      # 229 Swedish A
    s,&oslash;,o,g;     # 248 Norweigian o
    s,&Oslash;,O,g;     # 248 Norweigian O
    s,&uuml;,u,g;       # German u diaresis
    s,&Uuml;,U,g;       # German U diaresis
    s,&szlig;,ss,g;     # German ss
    s,&Szlig;,SS,g;     # German SS

    #   Remove unknown HTML tags like: &copy; #255;

    s/[&][a-zA-Z]+;//g;
    s/#\d+;//g;

    #   Remove punctuation

    s/[.,:;?!\'\"\`]/ /g;

    $debug  > 2 and   print "$id: -2- $ARG\n";

    #       Pick first 1-8 words for header name

    if (
           /($ws$ws$ws$ws$ws$ws$ws$ws$w)/o
        or /($ws$ws$ws$ws$ws$ws$ws$w)/o
        or /($ws$ws$ws$ws$ws$ws$w)/o
        or /($ws$ws$ws$ws$ws$w)/o
        or /($ws$ws$ws$ws$w)/o
        or /($ws$ws$ws$w)/o
        or /($ws$ws$w)/o
        or /($ws$w)/o
        or /($w)/o
       )
    {
        $ARG = $1;
    }

    $debug  > 2 and   print "$id: -3- $ARG\n";

    s/^\s+//;
    s/\s+$//;                           # strip trailing spaces
    s/\s/_/g;
    s/__/_/g;

    $debug  > 2 and   print "$id: -4- $ARG\n";

    lc $ARG;
}}

# ****************************************************************************
#
#   DESCRIPTION
#
#       After you have checked that line is header with  IsHeading()
#       the line is sent to here. It reformats the lie and
#
#       Contructs 1-5 first words to forn the TOC NAME reference
#
#   SETS GLOBALS
#
#       @HEADING_ARRAY      'heading', 'heading' ...
#                           The headings as they appear in the text.
#                           This is used as index when reading
#                           HEADING_HASH in ordered manner.
#
#       %HEADING_HASH       'heading' -- 'NAME(html)'
#                           Original headings from text. This is ordered
#                           as the heading apper in the text.
#
#   USES STATIC VARIABLES (closures)
#
#       %staticNameHash     'NAME(html)' -- 1
#                           We must index the hash in this order to find
#                           out if we clash duplicate NAME later in text.
#                           Remember, we only pick 1-5 unique words.
#
#       $staticCounter      Counts headings. This is used for NAME(html)
#                           rteference name if NAME_UNIQ option has been
#                           turned on.
#
#   INPUT PARAMETERS
#
#       $line       string, header line
#
#       $clear      [optional] if sent, then clear all related values.
#                   You should call with this parameter as a first invocation
#                   to this  function. The $line parameter is not used.
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

{
    my %staticNameHash;
    my $staticCounter;

sub HeaderArrayUpdate ($; $)
{
    my    $id  = "$LIB.HeaderArrayUpdate";
    local $ARG = shift;
    my ( $clear ) = shift;

    $debug  > 1 and  warn "$id: INPUT line [$ARG] clear [$clear]\n";

    if ( $clear )
    {
        # Because this function "remembers" values, a NEW
        # file handling must first clear the hash.

        @HEADING_ARRAY  = ();
        %HEADING_HASH   = ();
        %staticNameHash = ();
        $staticCounter  = 1;

        $debug > 2  and  print "$id: ARRAYS CLEARED .\n";

        return;
    }

    my $origHeading = $ARG;
    my $name        = $ARG ;            # the NAME html reference

    $debug  > 2 and  warn "$id: original: $ARG\n";

    #   When constructing names, the numbers may move,
    #   So it is more logical to link to words only when making NAME ref.
    #
    #       11.0 Using lambda notation --> Using lambda notation

    s/^\s*[0-9][0-9.]*//  if $FORGET_HEAD_NUMBERS;

    $debug  > 2 and  warn "$id: substitute A: $ARG\n";

    #   Kill characters that we do not want to see in NAME reference

    s/[-+,:!\"#%=?^{}()<>?!\\\/~*'|]//g;    # dummy for font-lock '

    $debug  > 2 and  warn "$id: substitute B: $ARG\n";

    #   Kill hyphens "Perl -- the extract language"
    #   --> "Perl the extract language"

    s/\s+-+//g;
    s/-+\s+//g;

    $debug  > 2 and  warn "$id: substitute D: $ARG\n";

    if ( $NAME_UNIQ )               # use numbers for AHREF name=""
    {
        $ARG = $staticCounter;
    }
    else
    {
        $ARG = MakeHeadingName $ARG;
    }

    #   If MakeHeadingName() Did not get rid of all &auml; and other
    #   special tokens, remove these characters now.

    s/[;&]//g;

    $debug  > 2 and  warn "$id: substitute E: $ARG\n";

    # ........................................ check duplicate clash ...

    if ( not defined $staticNameHash{ $ARG } ) # are 1-5 words unique?
    {
        $debug and warn "$id: Added $ARG\n";
        $staticNameHash{ $ARG } = $origHeading;     # add new
    }
    else
    {
        print "$id: $staticNameHash{$ARG}"; # current value

        PrintHash "$id: HEADING_HASH", \%HEADING_HASH, \*STDERR;

        warn Here <<"............EOF";

            $id:
            LINE NOW  : $origHeading
            ALREADY   : $staticNameHash{ $ARG }
            CONVERSION: [$name] --> [$ARG]

            Cannot pick 1-8 words to construct HTML <a name="...">
            fragment identifier, because there already is an entry
            with the same name. Please rename all heading so that they
            do not have the same first 1-5 words.

            Alternatively you have to turn on option --name-uniq which
            forces using numbered NAME fragment identifiers instead
            of more descriptive id strings from headings.

............EOF

        die;
    }

    # ............................................... update globals ...

    $debug  and  warn "$id: $origHeading -- $ARG\n";

    push @HEADING_ARRAY, $origHeading;

    $HEADING_HASH{ $origHeading } = $ARG;
    $staticCounter++;

    $ARG;

}} # close sub and static block

# ****************************************************************************
#
#   DESCRIPTION
#
#       Prepare Heading arrays for HTML. This fucntion should be called
#       first before doing any heading hathering.
#
#   INPUT PARAMETERS
#
#       None
#
#   RETURN VALUES
#
#       None
#
# ****************************************************************************

sub HeaderArrayClear ()
{
    my $id = "$LIB.HeaderArrayClear";
    HeaderArrayUpdate undef, -clear;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Start a heading. Only headings 1 and 2 are supported.
#
#   INPUT PARAMETERS
#
#       $header     the full header text
#       $hname      the NAME reference for this header
#       $level      heading level 1..x
#
#   RETURN VALUES
#
#       $           ready html text
#
# ****************************************************************************

sub MakeHeadingHtml ( % )
{
    my $id = "$LIB.PrintHeader";

    my %arg     = @ARG;
    my $header  = $arg{-header};
    my $hname   = $arg{-headerName};
    my $level   = $arg{-headerLevel};

    $debug  and  print "$id INPUT header [$header] hname [$hname]",
    , "level [$level]\n";

    my ($ret, $button) = ( "", "");

    $PRINT_NAME_REFS     and warn "NAME REFERENCE: $hname\n";

    if ( not $AS_IS and not $FRAME )
    {
        my $attr = qq( class="btn-toc" );

        #   It doesn't matter how the FONT is reduced, it
        #   won't make the [toc] button any smaller inside the <h> tag.
        #   -- too bad --

        if ( $OPT_HEADING_TOP_BUTTON )
        {
            my $toc = Language -toc;

            $button = qq(<font size"-2">)
            .  MakeUrlRef( "#toc", "[$toc]", $attr)
            .  "</font>"
            ;
        }

        if ( 0 )
        {
            $button = MakeUrlRef
            (
                    "#toc",
                    qq(<font size"-2">) . "[toc]" . "</font>"
                    , $attr
            );

        }
    }

    $header =~ s/^\s+//;
    $header = XlatTag2htmlSpecial $header;

    if ( $level == 1 )
    {
        my $hr = $AS_IS ? "" : $HTML_HASH{hr};

        $ret = HereQuote << "EOF";
            $HTML_HASH{p_end}
            $hr
                <a name="$hname"  id="$hname"></a>
                <h1>
                $header
                $button
                </h1>

EOF

    }
    elsif ( $level > 1 )
    {
        $ret = << "EOF";

$HTML_HASH{p_end}
  <a name="$hname" id="$hname"></a>
  <h2>
      $header
      $button
  </h2>



EOF
    }

    $ret;
}

# }}}
# {{{ Do the line, txt --> html

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return HTML table.
#
#   INPUT PARAMETERS
#
#       $text       Text to put inside table
#       $styleT     Style for table
#       $styleTD    Style for TDs
#
#   RETURN VALUES
#
#       html
#
# ****************************************************************************

sub HtmlTable ( $$$ )
{
    my $id = "$LIB.HtmlTable";
    my ( $text, $stylet, $styletd ) = @ARG;

    return qq(

<table  class="$stylet">
    <tr>
    <td class="$styletd" valign="top">
    $text
    </td>
    </tr>
</table>

    );
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return HTML code that is fixed. The basic DoLine() parser
#       is old and work line-by-line basis when it would have been better to
#       to work with multiple lines.
#
#       After all HTML has been generated, program calls this function
#       to give finishing touch to those glitches that remained in the
#       HTML.
#
#   INPUT PARAMETERS
#
#       \@html      Final HTML
#
#   RETURN VALUES
#
#       \@html      Fixed HTML
#
# ****************************************************************************

sub HtmlFixes ($)
{
    my $id = "$LIB.HtmlFixes";
    my ( $arrRef ) = @ARG;

    unless ( defined $arrRef )
    {
        warn "$id: [ERROR] \$arrRef is not defined";
        return;
    }

    local $ARG = join '', @$arrRef;

    if ( 1 )  # Enabled
    {
        my $tag = '\S+';  # $CSS_CODE_STYLE_NOTE;

        #   Search <pre> tags and change style to "shade-note"

        s{
            # $1
            (
                # $2
                <table \s+ class=\"([^\"]+)\"\s*>
                \s+    <tr>
                # $3
                \s+    <td \s+ class=\"([^\"]+)\"  \s+  valign=\"top\">
                \s+   <pre>[ ]*[\r\n]+
            )
            # $4, $5, $6
            (\s*$tag)(.+?)(</pre>) \s+
        }
        {
            my $orig    = $1;
            my $classT  = $2;
            my $classTD = $3;
            my $tagWord = $4;
            my $text    = $5;
            my $end     = $6;

            my $tagWord2 = XlatHtml2tag $tagWord; # Fix &gt; ==> ">"
            my $tagcss   = $tagWord2 =~ /$CSS_CODE_STYLE_NOTE/o;

            $debug > 7  and  print "$id: #STYLE-CSS [$CSS_CODE_STYLE_NOTE]"
                                 , " word [$tagWord] tagWord2 [$tagWord2]"
                                 , " tagcss [$tagcss]";

            my $pre     = 0;
            my $table   = $orig;
            my $found   = 0;

            if ( $tagcss )
            {
                $table =~ s/$classT\"/shade-note\"/g;
                $table =~ s/$classTD\"/shade-note-attrib\"/g;
                $table =~ s,<(?i:pre)>,<b>$tagWord</b>,;
                $end   = "";            # remove </pre>
                $found = 1;
            }
            elsif ( $tagWord2 =~ /t2html::(\S+)/ )
            {
                #   Command directives for table rendering
                #
                #   #t2html::td:bgcolor="#FFFFFF":tableclass:dashed
                #   #t2html::td:bgcolor="#FFFFFF":tableborder:1
                #   #t2html::td:class=color-beige

                my $directives = $1;
                $directives    =~ s/_/ /g;

                $tagWord = "";      # Kill first line
                $pre     = 1;       # Put PRE back

                while ( $directives =~ /([^:]+):([^:]+)/g )
                {
                    my ($key, $val) = ($1, $2);

                    #  Fix for the HTML
                    #  $key = class=color-beige
                    #  => $key = class="color-beige"

                    if ( $val =~ /=/  and  $val =~  /(.*)=([^\"']+)/ )
                    {
                        $val = qq($1="$2");
                    }

                    if ( $key eq 'td' )
                    {
                        $table =~ s/((?i:td[^>]+))class=.[^\"']+./$1$val/g;
                    }
                    elsif ( $key eq 'table' )
                    {
                        $table =~ s/((?i:table\s+))[^>]+/$1$val/g;
                    }
                    elsif ( $key =~ /table(\S+)/ )
                    {
                        $key   = $1;
                        $val   = qq("$val")  unless $val =~ /[\"']/;
                        $table =~ s/((?i:table[^>]+))$key=.[^\"]+./$1$key=$val/g;
                    }
                }
            }

            my ( $para, $rest ) = ("", "");

            #   This code is a bit hairy.
            #   - If there a paragraph (\n\s*\n), then treat it as
            #     individual TABLE.
            #   - After this initial pragraph, the rest of
            #     the text is returned back to the original <pre>

            if ( $found  and  $text =~ /\A(.+?\S)\n\s*\n(.+)/sgm )
            {
                ( $para, $rest ) = ( $1, $2 );

                $debug > 7  and  print "$id: PARAGRAPH [$para] [$rest]\n";

                $table = $orig;
                $text  = $rest;
                $pre   = 1;

                $para =  XlatWordMarkup ( XlatTag2html $para );
                $para = qq(<span class="note12">$tagWord</span> ) . $para;

                $para = HtmlTable $para, "shade-note", "shade-note-attrib";

                #  Fix HREF tags back to normal html.
                $para = XlatHtml2href $para;
            }
            else
            {
                $tagcss  and $tagWord = "";
                $text = (XlatTag2html $tagWord . $text);

                $debug > 7  and  print "$id: PARAGRAPH-ELSE tagcss [$tagcss]"
                                     , " found [$found] text [$text]\n";

                $found  and  $text = XlatWordMarkup $text;

                #  Fix HREF tags back to normal html.
                $text = XlatHtml2href $text;

                $debug > 7  and  print "$id: PARAGRAPH-ELSE (final) text [$text]\n";

                # Separate paragraphs
                # $text =~ s/^\s*$/    <p>/g;
            }

            $text .= "</pre>\n" if $pre and $text !~ /<pre/i;

            my $ret = $para . $table . $text . $end;

            $debug > 7  and  print "$id: REPLACED [$ret]\n";

            $ret;
        }esmgx;
    }

    #   There must be no gaps here
    #
    #       <pre>
    #
    #       code example
    #
    #       </pre>
    #
    #
    #   =>
    #       <pre>
    #       code example
    #       </pre>

    s,<(pre|code)>[ \t]*[\r\n]+,<$1>\n,igm;
    s,(?:\s*[\n\r])( *</(?:pre|code)>),$1,igm;

    #  Remove P before OL or UL - already fixed in DoLine().
    # s,<p>(<[ou]l>),$1,igm;

    #  Remove extra newline that is generated by <p>. </table>
    #  already adds one empty line.

    # s,(</table>\s+)<p\s+class="column7">,$1,gsmi;

    #  Remove extra gap before table
    #  s,<p>\s+(<table),$1,gsmi;

    #  Fix double closing

    s,</pre>(</pre>),$1,gi;

    #  Afer each heading(1), there must be paragraph marker
    #FIXME #TODO
    s,(</h1>\s+.*blockquote.*\s+)([^<]),$1<p>$2,gi;

    #  Afer each heading(2), there must be paragraph marker

    s,(</h[2-7]>\s+)([^<]),$1<p>$2,gi;

    #  Final clean up: remove trailing spaces

    s,[ \t]+$,,mg;

    #   Restore array and put newlines back.

    my $str = $ARG;
    my @arr =  map { $ARG .= "\n" } split '\n', $str;

    \@arr;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Substitute user tags given at --refrence "TAG=value". The values
#       are stored in %REFERENCE_HASH
#
#   INPUT PARAMETERS
#
#       $       Plain text
#
#   RETURN VALUES
#
#       $       formatted html line
#
# ****************************************************************************

sub DoLineUserTags ( $ )
{
    my $id          = "$LIB.DoLineUserTags";
    local ( $ARG )  = @ARG;

    # ........................................ substitute user tags ...

    while ( my($key, $value) = each %REFERENCE_HASH )
    {
        if ( /$key/ )
        {
            $debug  and  print "$id: $ARG -- KEY $key => VAL $value\n";

            s,$key,$value,gi;

            $debug  and  print "$id: $ARG";
        }
    }

    $debug  and  print "$id: RET [$ARG]\n";

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return HTML code to start <pre> section
#
#   INPUT PARAMETERS
#
#       None.       THe style is looked up in CDD_CODE_FORMAT
#
#   RETURN VALUES
#
#
#
# ****************************************************************************

sub HtmlCodeSectionEnd ()
{
    my $id = "$LIB.HtmlCodeSectionEnd";

    if ( $CSS_CODE_STYLE  ne  -notset )
    {
        #   This will format nicely in the generated HTML

        my $html = << "EOF";
    </pre>
    </td>
    </tr>
</table>
EOF
        $html;
    }
    else
    {
        "</pre>\n";
    }
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return HTML code to start <pre> section
#
#   INPUT PARAMETERS
#
#       None.       THe style is looked up in CDD_CODE_FORMAT
#
#   RETURN VALUES
#
#
#
# ****************************************************************************

sub HtmlCodeSectionStart ()
{
    my $id = "$LIB.HtmlCodeSectionStart";

    my $html;
    my %style =
    (
          -d3           => ["shade-3d"      , "shade-3d-attrib"]
        , -shade        => ["shade-normal"  , "shade-normal-attrib" ]
        , -shade2       => ["shade-normal2" , "shade-normal2-attrib" ]
    );

    if( $CSS_CODE_STYLE  ne  -notset
        and  my $arrRef = $style{$CSS_CODE_STYLE} )
    {
        my ( $class, $attrib ) = @{ $arrRef } ;


        $html = << "EOF";
<p>
<table class="$class">
    <tr>
    <td class="$attrib" valign="top">
    <pre>
EOF
    }
    else
    {
        $html = qq(\n<pre class="code">\n);
    }

    $debug > 6  and  print "$id: RET [$html]";

    $html;
}

# ************************************************************ &DoLine *******
#
#   DESCRIPTION
#
#       Add html tags per line basis. This function sets some global
#       states to keep track on bullet mode etc.
#
#   USES FUNCTION STATIC VARIABLES
#
#       $staticBulletMode   When bullet is opened, the flag is set to 0
#
#   INPUT PARAMETERS
#
#       $line
#
#   RETURN VALUES
#
#       $       formatted html line
#
# ****************************************************************************

{
    my $staticBulletMode = 0;
    my $staticPreMode    = 0;

    my $static7beg;
    my $static7end;

sub DoLine ( % )
{
    # .................................................... arguments ...

    my $id = "$LIB.DoLine";

    my %arg     = @ARG;
    my $file    = $arg{-file};
    my $input   = $arg{-line};
    my $base    = $arg{-base};
    my $line    = $arg{-lineNumber};
    my $arrayRef= $arg{-lineArrayRef};

    unless ( defined $arrayRef )
    {
        warn "$id: [ERROR] \$arrayRef is not defined";
        return;
    }

    not defined $input      and warn "$id: INPUT not defined?";
    not defined $line       and warn "$id: LINE not defined?";

    return "" if not defined $input;

    # ........................................................... $ARG ...

    local $ARG   = $input; chomp;
    my $origLine = $ARG;

    # ............................................... misc variables ...

    my
    (
        $s1
        , $s2
        , $hname
        , $tmp
        , $tmpLine
        , $beg
        , $end
    );

    my $spaces      = 0;
    my $bulletText  = "";
    my $i           = -1;
    my $br          = $HTML_HASH{br};

    # .................................... lines around current-line ...
    #       HEADER                  <-- search this
    #           <empty line>
    #           text starts here

    my $prev2   = "";
    $prev2      = $$arrayRef[ $line -2] if $line > 1;

    my $prev    = "";
    $prev       = $$arrayRef[ $line -1] if $line > 0;

    my $next    = "";
    $next       = $$arrayRef[ $line +1] if $line +1 < @$arrayRef ;

    my $prevEmpty   = 0;
    $prevEmpty      = 1 if $prev    =~ /^\s*$/;

    my $nextEmpty   = 0;
    $nextEmpty      = 1 if $next    =~ /^\s*$/;

    # ............................................... flag variables ...

    my( $AsIs, $hlevel, $isBullet );

    my $isCode      = 0;
    my $isText      = 0;
    my $isPcode     = 0;
    my $isBrCode    = 0;

    my $isPrevHdr   = 0;
    $isPrevHdr      = IsHeading $prev2   if $line > 1;

    my $isPureText  = 0;
    $tmp            = "  ";                     # 4 spaces
    $isPureText     = 1 if /^$tmp$tmp$tmp/o;    # {12}

    unless ( $static7beg )
    {
        $static7beg = $COLUMN_HASH{ beg7quote };
        $static7end = $COLUMN_HASH{ end7quote };
    }

    # ................................................. command tags ...

    if  ( /^( {1,11})\.([^ \t.].*)/ )
    {
        # The "DOT" code at the beginning of word. Notice that the dot
        # code is efective only at columns 1..11

        $debug > 6 and warn "BR $line <$ARG>\n";

        $isBrCode   = 1;
        $s1         = $1;
        $s2         = $2;
        $ARG = $s1 . $s2;    #       Remove the DOT control code
    }

    if ( /^([ \t]+),([^ \t,].*)/ )                  # The "P" tag
    {
        # Remove the command from the output.

        $isPcode    = 1;
        $s1         = $1;
        $s2         = $2;
        $ARG = $s1 . $s2;

        $debug > 6 and warn "P-code $line $ARG\n";
    }

    # .................................................. Strip lines ...
    # It is usual that the is "End of file" marker left flushed.
    # Strip that tag away and do not interpret it as a heading. Allow
    # optional heading numbering at front.
    #
    #    1.1  End
    #    1.2.3 End of document

    if
    (
        /^([\d.]*[\d]\s+)?End\s+of\s+(doc(ument)?|file).*$
         |
         ^([\d.]\s+)?End\s*$
        /xi
    )
    {
        #   This is the marked that ends the dokument of file. Do not
        #   print it.

        return "";
    }

    # ........................................ substitute user tags ...

    $ARG = DoLineUserTags $ARG;

    if( /#URL-BASE/ )
    {
        $debug > 6 and warn ">> $ARG";

        s,#URL-BASE,$base,gi;
    }

    $ARG = XlatTag2html $ARG;

    # ......................................................... &url ...

    $ARG = XlatRef       $ARG;
    $ARG = XlatPicture   $ARG;
    $ARG = XlatUrlInline $ARG;
    $ARG = XlatUrl       $ARG;
    $ARG = XlatMailto    $ARG;

    # .................................................... url-as-is ...

    if( /(.*)#URL-AS-IS-\s*(\S+)((?:&gt;|>).*)/ or
        /(.*)#URL-AS-IS-\s*(\S+)(.*)/
      )
    {
        my $before = $1;
        my $url    = $2;
        my $after  = $3;

        #   Extract the last part after directories "dir/dir/file.doc"

        my $name   = $url;

        if ( $url =~ m,.*/(.*), )
        {
            $name = $1;
        }

        $debug > 6 and warn "URL-AS-IS>> $url";

        $url =  qq(<a href="$url">$name</a>);

        $ARG = $before . $url . $after;
    }

    # ......................................................... &rcs ...

    #   The bullet text must be examined only after the expansions
    #   in the line

    $isBullet   = IsBullet $ARG, \$bulletText;
    $bulletText = XlatTag2htmlSpecial $bulletText  if $isBullet;

    # ................................................... study line ...

    if ( /^( +)[^ ]/ )
    {
        ($spaces) = /^( +)[^ ]/;
        $spaces   = length $spaces;
    }

    if ( /^ {8}[^ ]/o  )
    {
        $isText = 1;
    }
    # elsif ( /^$s1(!!)([^!\n\r]*)$/o )
    elsif ( /^ {4}(!!)([^!\n\r]*)/o )
    {
        #   A special !! code means adding <hr> tag

        if ( defined $2 )
        {
            $ARG = qq(\n<hr class="special"> \n)
                .  qq(\t <strong><em> $2 </em></strong>$br \n)
                ;
        }
        else
        {
             $ARG = "\n<hr> \n\t<!--  BREAK -->   $br\n";
        }
    }
    elsif ( $hlevel = IsHeading $ARG )
    {

        $debug > 1  and warn "$id: IsHeading ok, $hlevel, $ARG\n";

        $hname = HeaderArrayUpdate $ARG;
        $ARG   = MakeHeadingHtml -header => $ARG
                , -headerName            => $hname
                , -headerLevel           => $hlevel
                ;

        return $ARG;
    }
    elsif
    (       /^ {12,}[^ ]/
            and not $staticBulletMode
            and not $isBullet
    )
    {
            $AsIs       = 1;
            $isCode     = 1;

            #  Make it a little shorter by removing spaces
            #  Otherwise the indent level is too deep

            $debug > 6  and  print "$id: PRE before [$ARG]\n";

            $ARG = substr $ARG, 6;

            $debug > 6  and  print "$id: PRE after [$ARG]\n";

            # $beg = $COLUMN_HASH{beg12};
            # $end = $COLUMN_HASH{end12};
            # $ARG = $beg . $ARG . $end;
    }
    elsif ( /^ {7}\&quot;(.*)\&quot;/o  )
    {
        #  Remove quotes
        $ARG = $1;

        $debug > 1 and warn "pos7:$ARG\n";

        $beg = $static7beg;
        $end = $static7end;

        $ARG = $beg . $ARG . $end . $br;
        $spaces = 8;                    # for <p class=column8>
    }

    # ...................................................... picture ...

    if ( /IMG src=/i )
    {
        if (  $line > 0  and  $AsIs  and  $prevEmpty )
        {
            #  if the Image reference #PIC is placed to the code column,
            #  the <pre> tags are not good at all.

            if ( $staticPreMode )
            {
                #   Don't leave pictures inside pre tags.

                my $html = HtmlCodeSectionEnd();

                $ARG = "$html\n\n$ARG";
                $staticPreMode = 0;
            }
        }

        return "$ARG\n";
    }

    # .......................................................... PRE ...

    $ARG = XlatTag2htmlSpecial $ARG   unless  $AsIs;

    if ( $line > 0  and  $AsIs  and  $prevEmpty )
    {
        unless ( $staticPreMode )
        {
            my $html = HtmlCodeSectionStart();
            $ARG = $html . $ARG;

            $staticPreMode = 1   unless $staticPreMode;

            if ( $staticPreMode )
            {
                $debug > 6  and  print "$id: PRE-1 [$ARG]\n";
            }
        }
    }

    if ( not $AsIs and  $next !~ /^ {12,}[^ ]|^[\r\n]+$/ )
    {
        #   Next non-empty line terminates PRE mode

        if ( $staticPreMode )
        {
            my $html = HtmlCodeSectionEnd();
            $ARG = "$html$ARG";

            $staticPreMode = 0;

            $debug > 6  and  print "$id: PRE-0 [$ARG]\n";
        }
    }

    # disable, not needed

    if (  0  and  $staticPreMode  and $AsIs  and
          $CSS_CODE_STYLE  ne -notset
        )
    {
        $ARG .= $br;
    }


#print "[$origLine]\n[$ARG]\n>> pre mode = $staticPreMode as = $AsIs\n\n";

    # ...................................................... bullets ...

    $debug > 1 and  warn "$id: line $line: "
                , " spaces $spaces "
                , " PrevEmpty $prevEmpty "
                , " NextEmpty $nextEmpty "
                , " isPrevHdr $isPrevHdr "
                , " hlevel $hlevel "
                , " IsBR $isBrCode "
                , " isPcode $isPcode "
                , " IsBullet $isBullet "
                , " StaticBulletMode $staticBulletMode\n"
                , "ARG[$ARG]\n"
                , "next[$next]\n"
                ;

    if ( $isBullet and $prevEmpty  )
    {
        $s1 =   "<ul>";
        $s1 =   "<ol>" if $isBullet eq $BULLET_TYPE_NUMBERED;

        $ARG              = $s1 . "\n\t<li>" . $bulletText;
        $staticBulletMode = 1;
        $isBullet         = 0;  # we handled this. Marks as used.

        $debug > 1 and warn "______________BULLET ON [$isBullet] $ARG\n";
    }

    if ( ($isBullet or $staticBulletMode) and $nextEmpty )
    {
        $s1 =   "</ul>";
        $s1 =   "</ol>" if $isBullet eq $BULLET_TYPE_NUMBERED;

        $ARG = "<li>$bulletText" if $isBullet;

        if ( not $isPcode )
        {
            #   if previous paragraph does not contain P code,
            #   then terminate this bullet

            $staticBulletMode = 0;
            $ARG              = "\t$ARG</li>\n$s1\n\n";
        }
        else
        {
            $ARG = "\t$ARG\n<p>\n";             # Continue in bullet mode
        }

        $debug > 1 and warn "______________BULLET OFF [$isBullet] $ARG\n";
        $isBullet = 0;
    }

    if ( $isBullet )
    {
        my $end = "\t</li>\n"  if $staticBulletMode > 1;

        $ARG = "$end<li>$bulletText";
        $staticBulletMode++;
        $debug > 1  and warn "BULLET  $ARG\n";
    }

    # ...................................... determining line context ...

    #   LOGIC: the <p class=column8"> and all that
    #
    #   If this is column 8, suppose regular text.
    #   See if this is begining or end of paragraph.

    if ( $spaces  == 1  or  $spaces == 2 )
    {
        $AsIs = $isCode = 1;
    }

    $debug > 6 and print "$id: %%P-before%% $ARG\n";

#print qq(
#        $spaces > 0
#
#        and not $isCode
#
#        # if this the above line was header, we must not insert P tag,
#        # because it would double the line spacing
#        # BUT, if user has moved this line out of col 8, go ahead
#
#        and ( not $isPrevHdr or ($isPrevHdr and $spaces != 8 ))
#
#        and not $hlevel
#        and not $isBullet
#        and not $staticBulletMode
#
#        #   If user has not prohibited using P code
#
#        and not $isPcode
#
#        #   these tags do not need P tag, otw line doubles
#
#        and not /<pre>/i
#);

    if
    (
        $spaces > 0

        and not $isCode

        # if this the above line was header, we must not insert P tag,
        # because it would double the line spacing
        # BUT, if user has moved this line out of col 8, go ahead
        #
        # 2007-03-01 not used any more
        # and ( not $isPrevHdr or ($isPrevHdr and $spaces != 8 ))

        and not $hlevel
        and not $isBullet
        and not $staticBulletMode

        #   If user has not prohibited using P code

        and not $isPcode

        #   these tags do not need P tag, otw line doubles

        and not /<pre>/i
    )
    {
        my $code;

        $debug > 6 and
            print "$id: %%P-in%% prevEmpty [$prevEmpty] nextEmpty [$nextEmpty]\n";

        if ( $prevEmpty )
        {
            if ( exists $COLUMN_HASH{ "beg" . $spaces } )
            {
                $code = $COLUMN_HASH{ "beg" . $spaces };
                $ARG = "\n$code\n$ARG";
            }
            elsif ( $spaces <= 12 )
            {
                $code = " class=" . qq("column) . $spaces . qq(");
                $ARG = "\n<p$code>\n$ARG";
            }
        }

        if ( $nextEmpty )
        {
            if ( exists $COLUMN_HASH{ "end" . $spaces } )
            {
                $code = $COLUMN_HASH{ "end" . $spaces };
                $ARG .= $code . "\n";
            }
            elsif ( $spaces <= 12 )
            {
                # No </p> needed
            }
        }
    }

    $debug > 6 and print "$id: %%P-after%% $ARG\n";

    #   _WORD_  is strong
    #   *WORD*  is emphasised
    #   The '_' must preceede whitespace and '>' which could be
    #   html code ending character.

    #   do not touch "code" text above 12 column amd IMAGES

    if ( not $AsIs )
    {
        $ARG = XlatWordMarkup $ARG;

        #   If already has /P then do nothing.

        if ( $isBrCode  and  not m,</p>,i )
        {
            $ARG .= $br;
        }
    }

    # ...................................................... include ...

    if( /(.*)#INCLUDE-(\S+)(.*)/ )
    {
        my $dir = dirname $file;

        my $before = $1;
        my $url    = $2;
        my $after  = $3;
        my $mode   = "";

        if ( $url =~ /^raw:(.*)/ )
        {
            $mode = -raw;
            $url = $1;
        }

        my $out = UrlInclude -dir => $dir, -url => $url, -mode => $mode;

        unless ( $out )
        {
            warn "$id: Include error '$url' in [$file:$ARG]";
        }

        $ARG = $before . $out . $after;

    }

    $debug > 6  and  print "$id: RET [$ARG]\n";

    "$ARG\n";
}}

# }}}
# {{{ Main

# ****************************************************************************
#
#   DESCRIPTION
#
#       Handle htmlizing the file
#
#   INPUT PARAMETERS
#
#       \@content           text
#       $filename           Used in split mode only to generate multiple files.
#       $regexp             Split Regexp.
#       $splitUseFileNames  Use symbolic names instead of numeric filenames
#                           when splitting.
#       $auto               Flag or string.
#                           If 1, write directly to .html files. no stdout
#                           If String, then write to file.
#       $frame              Is frame html requested
#       $cache              boolean, start using URL cache.
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub HandleOneFile ( % )
{
    my $id  = "$LIB.HandleOneFile";

    my %arg                 = @ARG;
    my $txt                 = $arg{-array};
    my $file                = $arg{-file};
    my $regexp              = $arg{-regexp};
    my $splitUseFileNames   = $arg{-split};
    my $auto                = $arg{-auto};
    my $frame               = $arg{-frame};
    my $linkCheck           = $arg{-linkCheck};
    my $linkCheckOneLine    = $arg{-linkCheckOneLine};
    my $title               = $arg{-title};
    my $author              = $arg{-author};
    my $doc                 = $arg{-doc};
    my $email               = $arg{-email};
    my $metaDescription     = $arg{-metadescription};
    my $metaKeywords        = $arg{-metakeywords};

    unless ( defined $txt )
    {
        warn "$id: [ERROR] \$txt is not defined";
        return;
    }

    $debug  and  warn << "EOF";
$id: INPUT
    \%arg                 = @ARG;
    txt                 = $arg{-array};
    file                = $arg{-file};
    regexp              = $arg{-regexp};
    splitUseFileNames   = $arg{-split};
    auto                = $arg{-auto};
    frame               = $arg{-frame};
    linkCheck           = $arg{-linkCheck};
    linkCheckOneLine    = $arg{-linkCheckOneLine};
    title               = $arg{-title};
    author              = $arg{-author};
    doc                 = $arg{-doc};
    email               = $arg{-email};
    metaDescription     = $arg{-metadescription};
    metaKeywords        = $arg{-metakeywords};
EOF

    $debug      and  printf "$id: File [$file] content length [%d]\n", scalar @$txt;
    $debug > 2  and  print "$id: content <<<@$txt>>>\n";

    # ........................................................ local ...

    my ( $i, $line , @arr, $htmlArrRef);
    my $timeStart = time();

    unless ( defined @$txt[0] )
    {
        warn "$id: [$file] No input lines found"; # We got no input
        return;
    }

    # ..................................................... html2txt ...
    # - If text contain tag <html> in the begining of file then automatically
    #   convert the input into text

    if ( defined @$txt[2] and IsHTML $txt )
    {
        # warn "$id: Conversion to text:\n";
        # @$txt = split /\n/, Html2txt($txt);

        unless ( $LINK_CHECK or $LINK_CHECK_ERR_TEXT_ONE_LINE )
        {
            warn "$id: [WARNING] $file looks like HTML page.\n";
            die "$id: Did you meant to add option for link check? See --help"
        }
    }

    $txt =  DeleteEmailHeaders $txt     if $DELETE_EMAIL;

    #   We can't remove TOC if link check mode is on, because then the line
    #   numbers reported wouoldn't match the original if TOC were removed.

    @$txt = KillToc $txt  unless  $LINK_CHECK;

    #   handle split marks

    if ( defined $regexp )
    {
        @arr = SplitToFiles $regexp, $file, $splitUseFileNames, $txt;
        print join("\n", @arr), "\n" ;
        return;                             #todo:
    }

    #   Should we ignore some lines according to regexp ?

    if ( defined $DELETE_REGEXP  and  not $DELETE_REGEXP eq "")
    {
        @$txt = grep !/$DELETE_REGEXP/o, @$txt ;
    }

    @$txt = expand @$txt;                    # Text::Tabs

    if ( $linkCheck )
    {
        LinkCheckMain -file     => $file
                  , -array      => $txt
                  , -oneline    => $linkCheckOneLine
                  ;
        return;
    }
    else
    {
        HeaderArrayClear();

        for my $line ( @$txt )
        {
            if ( defined $line )
            {
                my $tmp = DoLine -line  => $line
                    , -file             => $file
                    , -base             => $BASE_URL
                    , -lineNumber       => $i++
                    , -lineArrayRef     => $txt
                    ;

                push @arr, $tmp;
            }
        }
    }

    $htmlArrRef = PrintHtmlDoc
        -arrayRef => \@arr
        , -lines  => scalar @$txt
        , -file   => $file
        , -type   => $OUTPUT_TYPE
        , -title  => $title
        , -autor  => $author
        , -doc    => $doc
        , -email  => $email
        , -metadescription => $metaDescription
        , -metakeywords    => $metaKeywords
        ;

    $htmlArrRef = HtmlFixes $htmlArrRef;

    my $timeDiff = time() -  $timeStart;

    if ( length $auto )
    {
        my ( $name, $path, $extension ) = fileparse $file, '\.[^.]+$'; #font '


        $debug  and  print "$id: fileparse [$name] [$path] [$extension]\n";


        if ( $auto =~ /../ )        # Suppose filename if more than 2 chars
        {
            $path = $auto;
        }

        my $htmlFile = $path . $name . ".html";

        $verb  and  warn "$id: output automatic => $htmlFile\n";

        if ( $frame )
        {
            $htmlFile =  FileFrameNameBody();
            WriteFile $htmlFile,  $htmlArrRef;

            #   This is the file browser wants to read. Printed to stdout

            $htmlFile = FileFrameNameMain();
        }
        else
        {
            $debug  and  print "$id: WRITE non-frame [$htmlFile]\n";
            WriteFile $htmlFile,  $htmlArrRef;
        }

        $htmlFile =~ s/$HOME_ABS_PATH/$HOME/  if defined $HOME_ABS_PATH;


        $PRINT      and print "$name\n";
        $PRINT_URL  and print "file:$htmlFile\n"
    }
    else
    {
        print @$htmlArrRef;
    }

    $time and  warn "Lines: ", scalar @$txt, " $timeDiff secs\n";
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Run the test page creation command
#
#   INPUT PARAMETERS
#
#       $cmd            Additional option to perl command
#       $fileText       Text file source
#       $fileHtml       [optional] Generated Html destination
#
#   RETURN VALUES
#
#       None
#
# ****************************************************************************

sub TestPageRun ( $ $ ; $ )
{
    my $id = "$LIB.TestPageRun";
    my ( $cmd, $fileText, $fileHtml ) = @ARG;

    not defined $fileHtml   and  $fileHtml = "";

    print "\n    Run cmd       : $cmd\n";

    my @ret = `$cmd`;

    if ( grep /fail/i, @ret )
    {
        print "$id: Please run the command manually and "
              . "use absolute path names";
    }
    else
    {
        print "    Original text : $fileText\n"
            , "    Generated html: $fileHtml\n"
            ;
    }

    print @ret   if @ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Print the test pages: html and txt and sample style sheet.
#
#   INPUT PARAMETERS
#
#       None
#
#   RETURN VALUES
#
#       None
#
# ****************************************************************************

sub TestStyle ()
{
    return qq(

/* An example CSS */

body
{
    font-family:    Georgia, "Times New Roman", times, serif;
    padding-left:   0px;
    margin-left:    30px;

    font-size:      12px;

    line-height:    140%;
    text-align:     left;
    max-width:      700px;
}

div.toc
{
    font-family:    Verdana, Tahoma, Arial, sans-serif;
    margin-left:    40px;
}

div.toc h1
{
    font-family:    Georgia, "Times New Roman", times, serif;
    margin-left:    -40px;
}

h1, h2, h3, h4
{
    color:          #6BA4DC;
    text-align:     left;
}

h1
{
    font-size:      20px;
    margin-left:    0px;
}

h2
{
    font-size:      14px;
    margin:         0;
    margin-left:    35px;
}

hr
{
    border:         0;
    width:          0%;
}

p
{
    text-align:     justify;
    margin-left:    3em;
}

pre
{
    margin-left:    35px;
}

li
{
    text-align:     justify;
}

p.column8
{
    text-align:     justify;
}

ul, ol
{
    margin-left:    35px;
}

.word-ref
{
    color:          teal;
}

em.word
{
    color:          #809F69;
}

samp.word
{
    color:          #4C9CD4;
    font-family:    "Courier New", Courier, monospace;
    font-size:      1em;
}

span.super
{
    /* superscripts */
    color:          teal;
    vertical-align: super;
    font-family:    Verdana, Arial, sans-serif;
    font-size:      0.8em;
}

span.word-small
{
    color: #CC66FF;
    font-family: Verdana, Arial, sans-serif;
}

table
{
    border:             none;
    width:              100%;
    cellpadding:        10px;
    cellspacing:        0px;
}

table tr td pre
{
    /*  Make PRE tables "airy" */
    margin-top:         1em;
    margin-bottom:      1em;
}

table.shade-normal
{
     color:             #777;
}

table.dashed
{
    color: Navy;

    border-top:         1px #00e6e8 solid;
    border-left:        1px #00e6e8 solid;
    border-right:       1px #00c6c8 solid;
    border-bottom:      1px #00c6c8 solid;
    border-width:       94%;
    border-style:       dashed; /* dotted */
}

/* End of CSS */


    );
}

sub TestPage ( $ )
{
    my $id = "$LIB.TestPage";

    # ............................................. initial settings ...

    my $destdir = "."; # GetHomeDir();
#    my $tmp  = "$destdir/tmp";
#
#    $destdir = $tmp  if  -d $tmp;
#
#    if ( not $destdir )
#    {
#        $destdir = $TEMPDIR || $TEMP || "/tmp";
#    }
#
#    unless ( -d $destdir)
#    {
#        die "[FATAL] Cannot find temporary directory to write test files to.";
#    }

    my $fileText1 = "$destdir/$PROGNAME-1.txt";
    my $fileHtml1 = "$destdir/$PROGNAME-1.html";

    my $fileText2 = "$destdir/$PROGNAME-2.txt";
    my $fileHtml2 = "$destdir/$PROGNAME-2.html";

    my $fileText3 = "$destdir/$PROGNAME-3.txt";
    my $fileHtml3 = "$destdir/$PROGNAME-3.html";

    my $fileText4 = "$destdir/$PROGNAME-4.txt";
    my $fileHtml4 = "$destdir/$PROGNAME-4.html";
    my $cssFile   = "$destdir/$PROGNAME-4.css";

    my $fileFrame = "$destdir/$PROGNAME-5.txt";

    # ............................................. write test files ...

    my $cmd;
    my @test = grep ! /__END__/, <DATA>;

    unless (@test)
    {
        die "[FATAL] Couldn't read DATA. Report this problem";
    }

    WriteFile $fileText1, \@test;
    WriteFile $fileText2, \@test;
    WriteFile $fileText3, \@test;
    WriteFile $fileText4, \@test;
    WriteFile $fileFrame, \@test;
    WriteFile $cssFile, TestStyle();

    local $ARG = $PROGRAM_NAME;

    if ( not m,[/\\], )
    {
        #   There is no absolute dir that we could refer to ourself.
        #   the -S forces perl to search the path, but what if the progrma
        #   is not in the PATH yet? --> failure.

        print "$id: WARNING No absolute PROGRAM_NAME $PROGRAM_NAME",
              "$id: The automatic call may fail, if program is not in \$PATH;"
              ;

        $cmd = "perl -S $PROGRAM_NAME";
    }
    else
    {
        $cmd = "perl $PROGRAM_NAME";
    }

    # ..................................................... generate ...

    TestPageRun
        "$cmd --css-code-bg --css-code-note=\"(?:Notice|Note):\""
        . "  --css-file=\"$cssFile\""
        . "  --quiet --simple --Out $fileText1"
        , $fileText1, $fileHtml1
        ;

    TestPageRun
        "$cmd --as-is --css-code-bg --css-code-note=\"(?:Notice|Note):\""
        . "  --Out $fileText2"
        , $fileText2, $fileHtml2
        ;

#     TestPageRun
#         "$cmd --css-font-normal --Out $fileText3"
#         , $fileText3, $fileHtml3
#         ;

#     TestPageRun
#         "$cmd --css-font-readable --Out $fileText4"
#         , $fileText4, $fileHtml4
#         ;


#    my $base =  $fileFrame;

#     TestPageRun
#         "$cmd --html-frame --print-url --Out $fileFrame"
#         # "$cmd -F --print-url --Out $fileFrame"
#         , $fileFrame
#         ;

    exit 0;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Read Web page
#
#   INPUT PARAMETERS
#
#       page    HTML page
#
#   RETURN VALUES
#
#       $content    plain text
#
# ****************************************************************************
{
    my $staticLibChecked = 0;
    my $staticLibStatus  = 0;

sub Html2Text ( @ )
{
    my  $id = "$LIB.Html2Text";
    my (@page) = @ARG;

    $debug  and  print "$id: CONTENT =>[[[@page]]]";

    unless ( $staticLibChecked )
    {
        $staticLibChecked = 1;
        $staticLibStatus = LoadUrlSupport();

        if ( not $staticLibStatus  and  $verb )
        {
            warn "$id: Cannot Convert to HTML. Please get more Perl libraries.";
        }
    }

    my $content   = join '', @page;
    my $formatter = new HTML::FormatText
                ( leftmargin => 0, rightmargin => 76);

    # my $parser = HTML::Parser->new();
    # $parser->parse( join '', @list );
    # $parser-eof();

    # $verb  and  $HTML::Parse::WARN = 1;

    my $html = parse_html( $content );

    $verb > 1  and  warn "$id: Making conversion\n";

    $content = $formatter->format($html);

    $html->delete();    # mandatory to free memory

    $debug  and  print "$id: RET =>[[[$content]]]";

    $content;
}}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Read Web page
#
#   INPUT PARAMETERS
#
#       url     URL address
#       mode    [optional] if option is [-text] convert page to text
#
#   RETURN VALUES
#
#       $content
#
# ****************************************************************************

{
    my $staticLibChecked = 0;
    my $staticLibStatus  = 0;

sub UrlGet ( $; $ )
{
    my  $id = "$LIB.UrlGet";
    my ($url, $opt) = @ARG;

    $debug  and  print "$id: OPT [$opt] Getting URL $url\n";


    unless ( $staticLibChecked )
    {
        $staticLibChecked = 1;
        $staticLibStatus = LoadUrlSupport();

        if ( not $staticLibStatus  and  $verb )
        {
            warn "$id: Cannot check remote URLs. Please get more Perl libraries.";
        }
    }

    unless ( $staticLibStatus )
    {
        $verb  and  print "$id: No URL support: $url\n";
        return;
    }

    my $ua      = new LWP::UserAgent;
    my $request = new HTTP::Request( 'GET' => $url );
    my $obj     = $ua->request($request);
    my $stat    = $obj->is_success;

    unless ( $stat )
    {
        warn "$id  ** error: $url ",  $obj->message, "\n";
        return;
    }

    my $content = $obj->content();
    my $ret     = $content;
    # my $head    = $obj->headers_as_string();

    if ( $opt )
    {
        $ret = Html2Text $content;

        if ( $ret =~ /TABLE NOT SHOWN/ )
        {
            $verb  and
                print "$id: HTML to text conversion failed. Using original.";

            $ret = $content;
        }
    }

    $content;
}}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Dtermine output directory.
#
#   INPUT PARAMETERS
#
#       File
#
#   RETURN VALUES
#
#       Sets globals ARG_PATH and ARG_DIR
#
# ****************************************************************************

sub OutputDir ( $ )
{
    my $id      = "$LIB.OutputDir";
    my ($file)  = @ARG;


    $ARG_PATH = $file;
    $ARG_PATH = "stdin" if $file eq '-';

    if ( $ARG_PATH eq "stdin" )
    {
        $ARG_PATH = "./stdout";
    }
    elsif ( $ARG_PATH !~ m,[/\\],  or $OUTPUT_DIR )
    {

        $debug  and  print "$id: output dir [$OUTPUT_DIR]\n";

        if ( not defined $OUTPUT_DIR  or  $OUTPUT_DIR =~ /^\.$|^\s*$/ )
        {
            $ARG_PATH  = cwd();
        }
        else
        {
           $ARG_PATH = $OUTPUT_DIR;
        }

        $debug  and  print "$id: arg_path 1 [$ARG_PATH]\n";

        $ARG_PATH .= "/"  if $ARG_PATH !~ m,/$,;
        $ARG_PATH .= basename $file;

        $debug  and  print "$id: arg_path 2 [$ARG_PATH]\n";
    }

    ($ARG_FILE, $ARG_DIR) = fileparse $ARG_PATH;

    $debug  and  print "$id: RET arg_file [$ARG_FILE] arg_dir [$ARG_DIR]\n";

    $ARG_FILE, $ARG_DIR;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Get file
#
#   INPUT PARAMETERS
#
#       $file       Can be URL
#       $dir        Default directory
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub GetFile ( % )
{
    my $id = "$LIB.GetFile";

    my %arg     = @ARG;
    my $file    = $arg{-file};
    my $dir     = $arg{-dir};

    if ( not $file  and  not $dir )
    {
        warn "$id: [ERROR] file and dir arguments are empty.";
        return;
    }

    my @content;

    $debug  and  print "$id: -file [$file] -dir [$dir]\n";

    if ( $file =~ m,://, )
    {
        my $content = UrlGet $file, -text;

        if ( $content )
        {
            for my $line ( split /\r?\n/, $content )
            {
                push @content, $line . "\n";
            }
        }
    }
    else
    {
        if ( $file !~ m,[\\/]|^[-~]$,  and $dir )
        {
            $file  = "$dir/$file";
        }

        unless ( -f $file )
        {
            warn "$id: [WARNING] does not look like a file [$file]";
            return;
        }

        local *FILE;

        unless ( open FILE, $file )
        {
            warn "$id: Cannot open [$file] $ERRNO" ;
        }
        else
        {
            @content = <FILE>;
        }

        close FILE              or warn "$id: Cannot close [$file] $ERRNO";
    }

    if ( $debug > 3 )
    {
        print "$id: file [$file] [$file] CONTENT-START ["
              , @content
              , "] CONTENT-END\n";
    }

    @content;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Initialize all global variables.
#
#   INPUT PARAMETERS
#
#       $verb           default verbose setting
#       \@argvRef       Original value of @ARGV
#       \@addArrRef     [optional] Options to add to @ARGV
#
#   RETURN VALUES
#
#       @ARGV           command line arguments that remain after processing
#
# ****************************************************************************

sub InitArgs (%)
{
    my $id  = "$LIB.InitArgs()";
    my %arg = @ARG;

    my $origOptVerb = $arg{-verb}     || '';
    my $argvRef     = $arg{-argv}     || [];
    my $addArrRef   = $arg{-argvadd}  || [];

    #   Put all #T2HTML-OPTION directived first and
    #   combine them with command line args, which should
    #   override any user directives in file.

    my @argv = @$argvRef         if  defined $argvRef;
    unshift @argv, @$addArrRef   if  defined $addArrRef;
    @ARGV = @argv;

    $debug  and  PrintArray "$id: ARGV (before) ", \@ARGV;

    #   We must undefine VERB, so that the detection will
    #   work in command line parser.

    ! $origOptVerb  and  undef $verb;

    HandleCommandLineArgs();

    $debug  and  PrintArray "$id: ARGV (after) ", \@ARGV;

    if ( defined $OPT_EMAIL  and  $OPT_EMAIL ne '' )
    {
        $OPT_EMAIL =~ s/[<>]//g;        # Do this automatic fix
        CheckEmail $OPT_EMAIL;
    }

    @ARGV;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Main entry point
#
#   INPUT PARAMETERS
#
#       none
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub Main ()
{
    #   The --debug option is recognized in HandleCommandLineArgs() but
    #   we want to know it immediately here

    my $cmdline = join ' ', @ARGV   if  @ARGV;

    if ( defined $cmdline  and  $cmdline =~ /(^|\s)(?:-d|--debug)[\s=]*(\d+)*/ )
    {
        PrintArray "Main() started - ARGV (orig) ", \@ARGV;

        $debug = defined $2 ? $2 : 1;
    }

    $debug  and  warn "main: ARGV before Initialize() call [@ARGV]\n";

    Initialize();

    my @origARGV    = @ARGV;
    my $origOptVerb = 0;

    my $id = "$LIB.Main";       # Must be after Initialize(), defined $LIB.

    $debug  and  warn "$id: ARGV before InitArgs() call [@ARGV]\n";

    @ARGV = InitArgs -verb => $origOptVerb
                   , -argv => \@origARGV;

    $debug  and  warn "$id: ARGV after InitArgs() call [@ARGV]\n";

    $origOptVerb = $verb;

    # ................................................... read file ...

    my $dir = cwd();

    #  One time at Emacs M-x shell buffer, these calls printed
    #  directoried without the leading '/home'. Go figure why.
    #
    #     perl -MCwd -e 'print cwd(),qq(\n);'
    #
    #  A retry with 'cd' command to the same directory fixed the problem.

    ! -d $dir   and  die "$id: [PANIC] Perl cwd() returned invalid dir $dir";

    unless ( @ARGV  )
    {
        warn "$id: No command line files, reading STDIN.";
        push @ARGV, "-";
    }

    for my $url ( @ARGV )
    {
        my @content = GetFile -file => $url,
                              -dir  => $dir;

        my ($outFile, $outDir) = OutputDir $url;

        # .............................................. auto detect ...
        # See if this file should be converted at all

        if ( $OPT_AUTO_DETECT )
        {
            local $ARG;
            my $ok;

            for ( @content )
            {
                /$OPT_AUTO_DETECT/o  and  $ok = 1, last;
            }

            unless ( $ok )
            {
                $verb  and  print "$id: [AUTO-DETECT] skip $url\n";
                next;
            }
        }

        # ....................................... ready to make html ...

        $verb  and  warn "$id: Handling URL [$url]\n";

        # ............................................... directives ...
        #  Read #T2HTML directives

        $debug > 3  and  print "$id: content before\n<<<\n@content>>>\n";

        my ($hashRef);
        ( $hashRef, @content ) = XlatDirectives @content;
        my %hash = %$hashRef;

        $debug > 3  and  print "$id: content after\n<<<\n@content>>>\n";

        #   Create local function to access the hash structure.

        sub Hash($; $);
        local *Hash = sub ($; $)
        {
            my ($key, $first) = @ARG;

            if ( exists $hash{$key} )
            {
                my $ref     = $hash{$key};
                my @values  = $first ? @$ref[0] : @$ref;

                if ( $debug > 2 )
                {
                    warn "$id.Hash: ($key, $first) => "
                       , join( '::', @values)
                       , "\n";
                }

                return shift @values   if @values == 1;
                return @values;
            }

            return ();
        };

        # Cancel all embedded options if user did not want them.

        %hash = () unless $OBEY_T2HTML_DIRECTIVES;

        my @options = Hash("option");

        if ( @options )
        {
            #   Parse user embedded command line directives

            $debug  and  PrintArray "$id: #T2HTML-OPTION list ($url) "
                                  , \@options;

            InitArgs -verb    => $origOptVerb
                   , -argv    => \@origARGV
                   , -argvadd => \@options;
        }

        my $title       = Hash("title", 1)  || "No title";
        my $doc         = $DOC              || Hash("doc", 1);
        my $author      = $AUTHOR           || Hash("author", 1);
        my $email       = $OPT_EMAIL        || Hash("email", 1);
        my $keywords    = $META_KEYWORDS    || Hash("metakeywords", 1);
        my $description = $META_DESC        || Hash("metadescription", 1);
        my $auto        = $OUTPUT_AUTOMATIC ? $outDir : "";

        if ( @content )
        {
            HandleOneFile -array    => \@content
                , -title            => $title
                , -doc              => $doc
                , -author           => $author
                , -email            => $email
                , -file             => $url
                , -regexp           => $SPLIT_REGEXP
                , -split            => $SPLIT_NAME_FILENAMES
                , -auto             => $auto
                , -frame            => $FRAME
                , -linkCheck        => $LINK_CHECK
                , -linkCheckOneLine => $LINK_CHECK_ERR_TEXT_ONE_LINE
                , -metakeywords     => $keywords
                , -metadescription  => $description
                ;
        }
    }

    LinkCache -action => '-write';
}

sub TestDriverLinkExtractor ()
{
    Initialize();
    my $id = "$LIB.TestDriverLinkExtractor";

    $debug = 1;

    for my $lib ( "LWP::UserAgent", "HTML::LinkExtractor" )
    {
        CheckModule "$lib"       or die "$id: $lib [ERROR] $ERRNO";
    }

    $MODULE_LINKEXTRACTOR_OK = 1;

    my $url = "http://www.tpu.fi/~jaalto";
    my $ua  = new LWP::UserAgent;
    my $req = new HTTP::Request( GET => $url);

    my $response = $ua->request( $req );

    if ( $response->is_success() )
    {
        my %hash = ReadLinksMain -file  => $url
                               , -array => [$response->content()]
                               ;

        PrintHash "$id: $url ", \%hash, \*STDOUT;
    }
    else
    {
        warn "$ERRNO";
    }
}

# TestDriverLinkExtractor;
Main();

# }}}

0;

__DATA__
t2html Test Page

        #T2HTML-TITLE           Page title is embedded inside text file
        #t2HTML-EMAIL           author@examle.com
        #T2HTML-AUTHOR          John Doe
        #T2HTML-METAKEYWORDS    test, html, example
        #T2HTML-METADESCRIPTION This is test page of program t2html

        Copyright (C) 1996-2007 Jari Aalto

        License: This material may be distributed only subject to
        the terms and conditions set forth in GNU General Public
        License v2 or later; or, at your option, distributed under the
        terms of GNU Free Documentation License version 1.2 or later
        (GNU FDL).

        This is a demonstration text of Perl Text To HTML
        converter.

    Headings

        The tool provides for two heading levels. Combined with
        bullets and numbered lists, it ought to be enough for most
        purposes, unless you really like section 1.2.3.4.5

        You can insert links to headings or other documents. The
        convention is interior links are made by joining the first
        four words of the heading with underscores, so they must be
        unique. A link to a heading below looks like this in the text
        document and generates the link shown. There also is syntax
        for automatically inserting a base URL (see the tool
        documentation).

        The following blue link is generated with markup code:
        # REF #Markup ;(Markup);

        #REF #Markup ;(Markup);

    Markup

        The markup here is mostly based on column position, meaning
        mostly no tags. The exceptions are special marks for bullets
        and for emphasis. See later sections for the effects of column
        position on the output HTML.

        .Text surrounded by = equals = comes out =another= =color=
        .Text surrounded by backquote/forward quote comes out `color' `
        .Text surrounded by * asterisks * comes out *italic* *text*
        .Text surrounded by _ underscores _ comes out _bold_
        .The long dash -- is signified with two consequent dashes (-)
        .The plus-minus is signified with (+) and (-) markers combined +-4
        .Big character "C" in parentheses ( C ) make a copyright sign (C)
        .Registered trade mark sign (R) is big character "R" in parentheses ( R )
        .Euro sign is small character "e" right after digit: 400e
        .Degree sign is number "0" in parentheses just after number: 5(0)C
        .Superscript is maerked with bracket immediately attached to text[see this]
        .Special HTML entities can embedded in a normal way, like: &times; &lt; &gt; &le; &ge; &ne; &radic; &minus; &alpha; &beta; &gamma; &#402; &divide; &laquo; &raquo; - &ndash; &mdash; &asymp; &equiv; &lsaquo; &rsaquo; &sum; &infin; &trade;


    Emacs minor mode

        If you use the advertised Emacs minor mode (tinytf.el) you can
        easily renumber headings as you revise the text. Test is also
        colorized as you edit content.

        The editing mode can automatically generate the table of
        contents and the HTML generator can use it to generate a two
        frame output with the TOC in the left frame as hotlinks to the
        sections and subsections.
        Visit http://freshmeat.net/projects/emacs-tiny-tools

    Bullets, lists, and links

        This is ordinary text.

        o   This is a bullet paragraph with a continuation mark
            (leading comma) in the last line. It will not work if the
            ,comma is on the same line as the bullet.

            This is a continued bullet paragraph. You use a leading
            comma in the last line of the previous block to make a
            continued item. This is ok except the paragraph fill code
            (for the previous paragraph) cannot deal with it. Maybe
            it is a hint not to do continued bullets, or a hint not to
            put the comma in until you are done formatting.

        o   The next bullet.  the sldjf sldjf sldkjf slkdjf sldkjf
            lsdkjf slkdjf sldkjf sldkjf lskdj flskdjf lskdjf lsdkjf.

        .   This is a numbered list, made with a '.' in column 8 of its
            first line and text in column 12. You may not have blank
            lines between the items.
        .   Clickable email <gork@ork.com>.
        .   Non-clickable email gork@ork.com.
        .   Clickable link: http://this.com
        .   Non-clickable link: -http://this.com.
        .   Clickable file: file:/home/gork/x.txt.

    Line breaking

        Ordinary text with leading dot(.) forces line breaks in the HTML.
        .Here is a line with forced break.
        .Here is another line thatcontains dot-code at the beginning.

    Specials

        You can use superscripts[1], multiple[(2)] and almost
        any[(ab)] and imaginable[IV superscripts]

Samples per column (heading level h1)

        These samples show the range of effects produced by writing
        text beginning in different columns.  The column numbers
        referred to are columns in the source text, not (obviously)
        the output. The column numbering is counted starting from 0,
        _not_ _number_ _1_.

 Column 1, is undefined and nothing special.

  Column 2, is undefined and nothing special.

   Column 3, plain text, with color

    Column 4, Next heading level (h2)

     Column 5, plain text, with color

      Column 6, This i used for long quotations. The text uses
      Georgia font, which is designed for web, but which is
      equally good for laser printing font.

       Column 7, bold, italic

       "Column 7, start and end with double quote. Use for inner TOPICS"

        Column 8, standard text _strong_ *emphasized*

         Column 9, font weight bold, not italic.

          Column 10, quotation text, italic serif. This text has been made a
          little smaller and condensed than the rest of the text.
          More quotation text. More quotation text. More quotation text.
          More quotation text. More quotation text. More quotation text.
          More quotation text. More quotation text. More quotation text.
          More quotation text. More quotation text. More quotation text.

           Column 11, another color, for questions, exercise texts etc.

            Note: It is possible to say something important at
            column 12, which is normally reserved for CODE.
            You must supply options --css-code-bg and
            --css-code-note=Note:

        Here is the code column 12:

            Note: Here is something important to tell you about this code
            This part of the text in first paragrah is rendered differently,
            because it started with magic word _Note:_ The rest of the
            pararagraphs are rendered as CODE.

            /* Column 12 code */
            /* 10pt courier navy */
            // col 12 and beyond stay as is to preserve code formatting.

            for( i=0 ; i < 10 ; i++ )
            {
                more();
                whatever();
            }

    Another level 2 heading (column 4)

        Here is more ordinary text.

Table rendering examples

        These examples make sense only if the options *--css-code-bg*
        (use gray background for column 12) and
        *--css-code-note=Note:* have been turned on. If orfer to take
        full advantage of all the possibilities, you should introduce
        yourself to the HTML 4.01 specification and peek the CSS code
        in the generated HTML: the *tableclass* can take an attribute
        of the embedded default styles.

            Note: This is example 1 and `--css-code-note' options
            reads 'First word' in paragraph at column 12 and
            renders it differently. You can attache code right after
            this note, which must occupy only one paragraph

            --css-code-note=REGEXP      Regexp matches 'First word'
            --css-code-bg

        Here is example 2 using table control code
        #t2html::tableborder:1

            #t2html::tableborder:1

            for ( i = 0; i++; i < 10 )
            {
                //  Doing something in this loop
            }

        Here is example 3 using table control code
        #t2html::td:bgcolor=#FFEEFF:tableclass:solid

            #t2html::td:bgcolor=#FFEEFF:tableclass:solid

            for ( i = 0; i++; i < 10 )
            {
                //  Doing something in this loop
            }

        Here is example 4 using table control code
        #t2html::td:bgcolor=#CCFFCC

            #t2html::td:bgcolor=#CCFFCC

            for ( i = 0; i++; i < 10 )
            {
                //  Doing something in this loop
            }

        Here is example 5 using table control code. Due to bug in
        Opera 7-9.x, this exmaple may now show correctly. Please use
        Firefox to see the effect.
        #t2html::td:bgcolor=#FFFFFF:tableclass:dashed

            #t2html::td:bgcolor=#FFFFFF:tableclass:dashed

            for ( i = 0; i++; i < 10 )
            {
                //  Doing something in this loop
            }

        Here is example 6 using multiple table control codes. Use
        underscore sccharacter to separate different table attributes
        from each other. The underscore will be vconverted into
        SPACE. The double quotes around the VALUE are not strictly
        required by HTML standard, but they are expected in XML.
        #t2html::td:bgcolor="#EAEAEA":table:border=1_border=0_cellpadding="10"_cellspacing="0"

            #t2html::td:bgcolor="#EAEAEA":table:border=1_border=0_cellpadding="10"_cellspacing="0"

            for ( i = 0; i++; i < 10 )
            {
                //  Doing something in this loop
            }

        Here is example 7 using table control code
        #t2html::td:class=color-navy:table:cellpadding=0 which cancels
        default grey coloring. The cellpadding must be zeroed, around
        the text to make room.

            #t2html::td:class=color-white:table:cellpadding=0

            for ( i = 0; i++; i < 10 )
            {
                //  Doing something in this loop
            }

Conversion program

        The perl program t2html turns the raw technical text format
        into HTML. Among other things it can produce HTML files with
        an index frame, a main frame, and a master that ties the two
        together. It has features too numerous to list to control the
        output. For details see the perldoc than is embeddedinside the
        program:

            perl -S t2html --help | more

        The frame aware html pages are generated by adding the
        *--html-frame* option.

__END__
