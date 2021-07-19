=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Tools::Sanitize;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(strict_clean);

use HTML::Entities qw(encode_entities_numeric);
use URI;

sub strict_clean {
  my @stack;
  my $out = "";

  my @good_tags = qw(p a i b em br);
  my @auto_close = qw(br);
  my %good_attrs = ( a => { href => 'url' });
  my %more_attrs = ( a => { target => '_blank' } );
  foreach $_ (split(/(?=[<>])/,$_[0])) {
    s/^>//;
    if(/^<\//) {
      my $tag = $_;
      unless(grep { $_ eq $tag } @auto_close) {
        $tag = pop @stack;
        $out .= "</$tag>";
      }
    } elsif(s/^<//) {
      s/^(\S+)//;
      my $tag = lc $1;
      next unless grep { $_ eq $tag } @good_tags;
      push @stack,$tag;
      my %attrs;
      foreach my $attr (keys %{$good_attrs{$tag}||{}}) {
        if(s/$attr=(["'])(.*?)\1//) {
          my $value = $2;
          if($good_attrs{$tag}{$attr} eq 'url') {
            $value =~ s/[<>'"]//g;
            my $uri = URI->new($value);
            if($uri->scheme =~ /^https?$/ and
              $uri->host =~ /^[\w\.]+$/) {
              $value = $uri->canonical->as_string;
            } else {
              $value = undef;
            }
          }
          $attrs{$attr} = $value if defined $value;
        }
      }
      foreach my $attr (keys %{$more_attrs{$tag}||{}}) {
        $attrs{$attr} = $more_attrs{$tag}->{$attr};
      }
      $out .= "<$tag";
      foreach my $attr (keys %attrs) {
        my $value = $attrs{$attr};
        $value =~ s/["'<>]//g;
        $out .= " $attr=\"$value\"";
      }
      if(grep { $_ eq $tag } @auto_close) {
        pop @stack;
        $out .= "/";
      }
      $out .= ">";
    } else {
      $out .= encode_entities_numeric($_);
    }
  }
  while(@stack) { $out .= "</".pop(@stack).">"; }
  return $out;
}

1;

