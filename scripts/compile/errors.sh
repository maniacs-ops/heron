#!/usr/bin/env perl

# *************************************************************
#
# usage: <this-script> [-list listfile] [-e] [-t] filename [filename]*
#
# -e generate enums and error messages
# -t generate #defines and error messages
#
# (both -e and -t can be used)
#
# -list: generate a list of error codes instead of other outputs
#
# *************************************************************
#
# INPUT: any number of sets of error codes for software
#       layers called "name", with (unique) masks as follows:
#
#       name = mask {
#       ERRNAME Error string
#       ERRNAME Error string
#        ...
#       ERRNAME Error string
#       }
#
#  (mask can be in octal (0777777), hex (0xabcdeff) or decimal
#   notation)
#
#       If you want the error_info[] structure to be part of a class,
#       put the class name after the mask and groupname and before the open "{"
#       for the group of error messages; in that case the <name>_einfo_gen.h
#       file will look like:
#               heron::error::error_info_t <class>::error_info[] = ...
#       If you don't do that, the name of the error_info structure will
#       have the <name> prepended, e.g.:
#               heron::error::error_info_t <name>_error_info[] = ...
#
# *************************************************************
#
# OUTPUT:
#  for each software layer ("name"), this script creates:
#       <name>-errmsg-gen.h (-m)
#       <name>-einfo-gen.h  (-p)
#       <name>-einfo-bakw-gen.h (-p)
#       <name>-error-enum-gen.h (-e)
#       <name>-error-def-gen.h (-d)
#
#       name-error-gen.h  contains a static char * array, each element is
#               the error message associated with an error code
#       name-einfo-gen.h  contains a definition of a error_info_t array
#               for use with the error package.
#       name-error-gen.h  contains an enumeration for the
#               error codes , and an enum containing e_ERRMIN & e_ERRMAX
#       name-error-def-gen.h contains the #defined constants for the error
#               codes, and for minimum and maximum error codes
#
# *************************************************************

use strict;
use Getopt::Long;

sub Usage
{
    my $progname = $0;
    $progname =~ s/.*[\\\/]//;
    print STDERR <<EOF;
Usage: $progname [-t] [-e] filename...
Generate C++ code representing error information from file.
You must specify one of -t or -e
    
    --t          generate #defines and error messages 
    --e          generate enums and error messages
    --help|h     print this message and exit
    --list       generate list of error codes instead of other outputs
EOF
}

my %options = (m => 0, p => 0, e => 0, d => 0, help => 0, 'list' => '');
my @options = ("m!", "p!", "e!", "d!", "help|h", "list=s");
my $ok = GetOptions(\%options, @options);
$ok = 0 if $#ARGV == -1;
my $m = $options{m};
my $p = $options{p};
my $e = $options{e};
my $d = $options{d};
$ok = 0 if (!$m && !$p && !$e && !$d);

if (!$ok || $options{help})  {
    Usage();
    die(!$ok);
}

my ( $list, $listfile );
$list = 0;
$list = 1, $listfile = $options{'list'}  if ( $options{'list'} ne '' );
my $timeStamp = localtime;

sub MakeStdHeader
{
    my ($fileName, $baseName) = @_;
    my $headerExclusionName = uc($baseName);
    $headerExclusionName =~ tr/A-Z0-9/_/c;
    
    my $header = <<EOF;
#ifndef $headerExclusionName
#define $headerExclusionName

/* 
 * DO NOT EDIT --- 
 *     generated by $0 from $fileName
 *     generated on $timeStamp 
 *
 * <std-header orig-src='lx-server' genfile='true'>
 *
 * Locomatix Server
 *
 * Copyright (c) 2009-2010 Locomatix, Inc., Santa Clara, CA
 * All Rights Reserved.
 *
 */

/*  -- do not edit anything above this line --   </std-header>*/
EOF
    return $header;
}


sub GenErrorFiles
{
    my ($fileName, $baseName, $base, $groupName, $className, $m, $p, $e, $d, @lines) = @_;
    $className .= '::' if $className;
    $base = oct($base) if $base =~ /^0/;
    my $arrayPrefix = $className || "${baseName}_";
    my $num = 0;
    my $uBaseName = uc($baseName);
    
    my $errorMsgName = "${baseName}-errmsg-gen.h";
    my $errorInfoName = "${baseName}-einfo-gen.h";
    my $errorEnumName = "${baseName}-error-enum-gen.h";
    my $errorDefName = "${baseName}-error-def-gen.h";
    my $errorInfoBakwName = "${baseName}-einfo-bakw-gen.h";

    if ( ! $list ) {
        open MSG_OUT, ">$errorMsgName" or die "Couldn't open $errorMsgName" if ($m);
        open INFO_OUT, ">$errorInfoName" or die "Couldn't open $errorInfoName" if ($p);
        open ENUM_OUT, ">$errorEnumName" or die "Couldn't open $errorEnumName" if ($e);
        open DEF_OUT, ">$errorDefName" or die "Couldn't open $errorDefName" if ($d);
        open INFOBAKW_OUT, ">$errorInfoBakwName" or die "Couldn't open $errorInfoBakwName" if ($p);
        
        print MSG_OUT MakeStdHeader($fileName, $errorMsgName) if ($m);
        print INFO_OUT MakeStdHeader($fileName, $errorInfoName) if ($p);
        print ENUM_OUT MakeStdHeader($fileName, $errorEnumName) if ($e);
        print DEF_OUT MakeStdHeader($fileName, $errorDefName) if ($d);
        print INFOBAKW_OUT MakeStdHeader($fileName, $errorInfoBakwName) if ($p);
        
        print MSG_OUT "static char* ${baseName}_errmsg[] = {\n" if ($m);
        print INFO_OUT "heron::error::error_info_t ${arrayPrefix}error_info[] = {\n" if ($p);
        print ENUM_OUT "enum {\n" if ($e);
        print INFOBAKW_OUT "heron::error::error_info_t ${baseName}_error_info_bakw[] = {\n" if ($p);
    }
    
    foreach my $line (@lines)  {
	my ($tag, $msg);
        if ($line =~ /\s*(\S*)\s*(.*)/)  {
            ($tag, $msg) = ($1, $2);
            chomp $msg;
        }  else  {
            die "bad line $line";
        }
        my $dTag = "${baseName}_$tag";
        my $eTag = "${uBaseName}_$tag";
        
        if ( $list ) {
            print LIST sprintf("%s_%s = %s\n", $baseName, $tag, $num + 1);
	} else {
            print MSG_OUT sprintf("/* %-25s */ \"%s\",\n", $m ? $eTag : $dTag, $msg) if ($m);
            print INFO_OUT sprintf("    { %-25s,  \"%s\" },\n", $p ? $eTag : $dTag, $msg) if ($p);
            print ENUM_OUT sprintf("    %-25s = 0x%x,\n", $eTag, $base + $num) if ($e);
            print DEF_OUT sprintf("#define %-25s 0x%x\n", $dTag, $base + $num) if ($d);
            print INFOBAKW_OUT "    { $eTag, \"$eTag\" },\n" if ($p);
        }        
        $num++;
    }
    $num--;
        
    return  if ( $list );

    if ($m) {
      print MSG_OUT <<EOF;
	"dummy error code"
};

const ${baseName}_msg_size = $num;

#endif
EOF
    }

    print INFO_OUT "};\n\n" if ($p);
    print INFO_OUT sprintf("const sp_uint32 %-25s = %d; ", "${uBaseName}_ERRCNT", $num+1) if ($p);
    print INFO_OUT "\n\n#endif\n" if ($p);

#    print ENUM_OUT sprintf("    %-25s = 0x%x,\n", "${uBaseName}_OK", 0) if ($e);
    print ENUM_OUT sprintf("    %-25s = 0x%x,\n", "${uBaseName}_ERRMIN", $base) if ($e);
    print ENUM_OUT sprintf("    %-25s = 0x%x\n", "${uBaseName}_ERRMAX", $base + $num) if ($e);
    print ENUM_OUT "};\n\n#endif\n" if ($e);

#    print DEF_OUT sprintf("#define %-25s 0x%x\n", "${baseName}_OK", 0) if ($d);
    print DEF_OUT sprintf("#define %-25s 0x%x\n", "${baseName}_ERRMIN", $base) if ($d);
    print DEF_OUT sprintf("#define %-25s 0x%x\n", "${baseName}_ERRMAX", $base + $num) if ($d);
    print DEF_OUT "\n#endif\n" if ($d);
    
    print INFOBAKW_OUT "};\n\n#endif\n" if ($p);
    
    close MSG_OUT, or die "Couldn't close $errorMsgName" if ($m);
    close INFO_OUT, or die "Couldn't close $errorInfoName" if ($p);
    close ENUM_OUT, or die "Couldn't close $errorEnumName" if ($e);
    close DEF_OUT, or die "Couldn't close $errorDefName" if ($d);
    close INFOBAKW_OUT, or die "Couldn't close $errorInfoBakwName" if ($p);
}


sub ProcessFile
{
    my ($fileName, $m, $p, $e, $d) = @_;
    my ($baseName, $base, $groupName, $className, @lines);
    
    my $line;
    open INFILE, "<$fileName" or die "Couldn't open $fileName";
    while (defined($line = <INFILE>))  {
        next if $line =~ /^\s*\#/ || $line =~ /^\s*$/;
        if ($line =~ /^\s*(\S+)\s*=\s*([0-9A-Fa-fxX]+)\s*(".*")\s*(\S*)\s*{/)  {
            ($baseName, $base, $groupName, $className) = ($1, $2, $3, $4);
        }  elsif ($line =~ /^\s*}/)  {
            GenErrorFiles($fileName, $baseName, $base, $groupName, $className, $m, $p, $e, $d, @lines);
            undef $baseName;
            undef $base;
            undef $groupName;
            undef $className;
            undef @lines;
        }  else  {
            push @lines, $line;
        }
    }
    
    die "missing }" if defined $baseName;
}

if ( $list ) {
    open LIST, ">$listfile" or die "Couldn't open $listfile";
}
foreach my $file (@ARGV)  {
    ProcessFile($file, $m, $p, $e, $d);
}
close LIST  if ( $list );