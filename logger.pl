#!/usr/bin/perl

use strict;

use POSIX qw/strftime/;

$|=1;
while (<>) {
        print strftime('%Y%m%d-%H:%M:%S',localtime). " " . $_;
}
