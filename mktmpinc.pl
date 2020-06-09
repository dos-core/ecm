#! /usr/bin/perl

# mktmpinc -- Make temporary include files from macros
#  by C. Masloch, 2020
#
# Usage of the works is permitted provided that this
# instrument is retained with the works, so that any entity
# that uses the works is notified of this instrument.
#
# DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

# Reason to use this: https://bugzilla.nasm.us/show_bug.cgi?id=3392679
# Example usage: https://hg.ulukai.org/ecm/ldosboot/rev/b394f54d9d31

use warnings;
use strict;

sub trim {
  my $str = shift;
  $str =~ s/^\s+|\s+$//g;
  return $str;
};

our $emitting = 0;
our $emitted = 0;
our $ff;
our $fname;
our $lines = 0;
our $files = 0;
our $doseol = 0;
our $lastname = "";
our $currentname;

while (<<>>) {
  $currentname = $ARGV;
  if ($currentname ne $lastname) {
    if ($emitting) {
      die "Missing file delimiter in \"".$lastname."\"\n";
    }
    $files += 1;
  }
  $lastname = $currentname;
  $lines += 1;
  if (/\r$/) {
    $doseol = 1;
  } else {
    $doseol = 0;
  }
  if (/^\s*(#|;|\/\/|\/\*)?\s*===/) {
    if ($emitting) {
      if (not /===\s*eof\s*===/) {
        die "Invalid file delimiter in \"".$lastname."\"\n";
      }
      print "Emitted $emitted lines to \"$fname\" from \"".$lastname."\"\n";
      $emitting = 0;
      $emitted = 0;
      close($ff);
    } else {
      if ($_ =~ /^(.*)===\s*(\S*\.\S*)\s*===(.*)$/) {
        $fname = $2;
        my $commentstart = trim($1);
        my $commentend = trim($3);
        open($ff, ">", $fname)
          or die "Cannot open output file \"$fname\" from \"".$lastname."\": $!\n";
        $emitting = 1;
        if ($commentstart =~ /\S/) {
          print $ff $commentstart." ";
        }
        print $ff "Auto-generated file, do not edit.";
        if ($commentend =~ /\S/) {
          print $ff " ".$commentend;
        }
        if ($doseol) {
          print $ff "\r\n\r\n";
        } else {
          print $ff "\n\n";
        }
      } else {
        die "Invalid filename in \"".trim($_)."\" from \"".$lastname."\"\n";
      }
    }
    next;
  }
  if ($emitting) {
    print $ff $_;
    $emitted += 1;
  }
};

if ($emitting) {
  die "Missing file delimiter in \"".$lastname."\"\n";
}

print "Processed $lines lines in $files files\n";
