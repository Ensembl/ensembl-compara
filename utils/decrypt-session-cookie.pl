#!/software/bin/perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


#
# Decrypts session cookie hex string (supplied as $ARGV[0]) using secrets
# on server on which it is running or otherwise $ARGV[1,2,3,4] as
# ENSEMBL_ENCRYPT_{0,1,2,3} from that machine's SiteDefs.
#
# The decryption algorithm isn't secret, so there's nothing revelatory
# about this script: the secrecy is from the supplied key material.
#
# eg.
#
# ./utils/decrypt-session-cookie.pl 9608afbab558004a095e7ef2510bc4200ddf299d85677edffae04993 
#
# ./utils/decrypt-session-cookie.pl 9608afbab558004a095e7ef2510bc4200ddf299d85677edffae04993 0x123456 Bb Cc Dd
#
# 

use strict;
use warnings;
use Digest::MD5;

use FindBin qw($Bin);
BEGIN{
  unshift @INC, "$Bin/../conf";
  eval{ require SiteDefs; SiteDefs->import; };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

my $cookie = $ARGV[0];
die "Must supply cookie" unless $cookie;

my @key = @ARGV[1..4];
if(grep { not defined $_ } @key) {
  $key[0] ||= $SiteDefs::ENSEMBL_ENCRYPT_0;
  $key[1] ||= $SiteDefs::ENSEMBL_ENCRYPT_1;
  $key[2] ||= $SiteDefs::ENSEMBL_ENCRYPT_2;
  $key[3] ||= $SiteDefs::ENSEMBL_ENCRYPT_3;
}
$key[0] = hex($key[0]) if $key[0] =~ /^0x/;

my $rand1 = substr($cookie,16,8);
my $time = substr($cookie,24,8);
my $rand2 = substr($cookie,32,8);

my $value = ((hex($rand1)^hex($rand2))-$key[0]) & 0x0fffffff;
my $enc =  crypt($rand1,$key[1]).
           crypt($time,$key[2]).
           crypt($rand2,$key[3]);
my $md5d = Digest::MD5->new->add($enc)->hexdigest;
my $cookie2 = substr($md5d, 0, 16).$rand1.$time.$rand2.substr($md5d, 16, 16);

printf("value=%d time = %d (now = %d, expired = %s) verifies = %s\n",
       $value,hex($time),time,(time>hex($time)?'y':'n'),
       ($cookie eq $cookie2)?'y':'n');

1;
