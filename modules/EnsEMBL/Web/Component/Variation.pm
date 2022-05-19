=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Variation;

use strict;

use base qw(EnsEMBL::Web::Component);

sub trim_large_allele_string {
  my $self        = shift;
  my $allele      = shift;
  my $cell_prefix = shift;
  my $length      = shift;
  
  $length ||= 50;
  return $self->trim_large_string($allele,$cell_prefix,sub {
    # how to trim an allele string...
    my $trimmed = 0;
    my @out = map {
      if(length $_ > $length) {
        $trimmed = 1;
        $_ = substr($_,0,$length)."...";
      }
      $_;
    } (split m!/!,$_[0]);
    $out[-1] .= "..." unless $trimmed;
    return join("/",@out);
  });
}

# Population external links
sub pop_url {
  ### Arg1        : Population name (to be displayed)
  ### Arg2        : dbSNP population ID (variable to be linked to)
  ### Arg3        : Population display label (optional)
  ### Example     : $self->pop_url($pop_name, $pop_dbSNPID);
  ### Description : makes pop_name into a URL
  ### Returns  string

  my ($self, $pop_name, $pop_dbSNP, $pop_label) = @_;

  my $hub = $self->hub;

  my $pop_url;

  $pop_label = $pop_name if (!$pop_label);

  if($pop_name =~ /^1000GENOMES/) {
    $pop_url = $hub->get_ExtURL('1KG_POP', $pop_label);
  }
  elsif ($pop_name =~ /ALFA/i) {
    $pop_url = $hub->get_ExtURL('ALFA_POP');
  }
  elsif ($pop_name =~ /GEM-J/i) {
    $pop_url = $hub->get_ExtURL('GEM_J_POP');
  }
  elsif ($pop_name =~ /^NextGen/i) {
    $pop_url = $hub->get_ExtURL('NEXTGEN_POP');
  }
  elsif ($pop_name =~ /^ExAC/i) {
    $pop_url = $hub->get_ExtURL('EXAC_POP');
  }
  elsif ($pop_name =~ /^PRJ([A-Z]{2})\d+/i) {
    $pop_url = $hub->get_ExtURL('EVA_STUDY').$pop_name;
  }
  else {
    $pop_url = ($pop_dbSNP && $pop_dbSNP->[0] ne '' && $hub->species eq 'Homo_sapiens') ? $hub->get_ExtURL('DBSNPPOP', $pop_dbSNP->[0]) : undef;
  }
  return $pop_url;
}

sub pop_link {
  ### Arg1        : Population name (to be displayed)
  ### Arg2        : dbSNP population ID (variable to be linked to)
  ### Arg3        : Population label (optional)
  ### Example     : $self->pop_link($pop_name, $pop_dbSNPID, $pop_label);
  ### Description : makes pop_name into a link
  ### Returns  string

  my ($self, $pop_name, $pop_dbSNP, $pop_label) = @_;

  my $hub = $self->hub;

  my $pop_link;

  $pop_label = $pop_name if (!$pop_label);

  if($pop_name =~ /^1000GENOMES/) {
    $pop_link = $hub->get_ExtURL_link($pop_label, '1KG_POP', $pop_name);
  }
  elsif ($pop_name =~ /^NextGen/i) {
    $pop_link = $hub->get_ExtURL_link($pop_label, 'NEXTGEN_POP', $pop_name);
  }
  else {
    $pop_link = ($pop_dbSNP && $hub->species eq 'Homo_sapiens') ? $hub->get_ExtURL_link($pop_label, 'DBSNPPOP', $pop_dbSNP->[0]) : $pop_label;
  }
  return $pop_link;
}

1;
