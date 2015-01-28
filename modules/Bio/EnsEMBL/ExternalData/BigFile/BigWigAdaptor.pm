=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::ExternalData::BigFile::BigWigAdaptor;
use strict;

use Data::Dumper;
use Bio::DB::BigFile;
use Bio::DB::BigFile::Constants;
my $DEBUG = 0;


sub new {
  my ($class, $url) = @_;
  
  my $self = bless {
    _cache => {},
    _url => $url,
  }, $class;
      
  return $self;
}

sub url { return $_[0]->{'_url'} };

sub bigwig_open {
  my $self = shift;

  Bio::DB::BigFile->set_udc_defaults;
  $self->{_cache}->{_bigwig_handle} ||= Bio::DB::BigFile->bigWigFileOpen($self->url);
  return $self->{_cache}->{_bigwig_handle};
}

sub check {
  my $self = shift;

  my $bw = $self->bigwig_open;
  return defined $bw;
}

# UCSC prepend 'chr' on human chr ids. These are in some of the BigWig
# files. This method returns a possibly modified chr_id after
# checking whats in the BigWig file
sub munge_chr_id {
  my ($self, $chr_id) = @_;
  my $bw = $self->{_cache}->{_bigwig_handle} || $self->bigwig_open;
  
  warn "Failed to open BigWig file " . $self->url unless $bw;
  
  return undef unless $bw;

  my $list = $bw->chromList;
  my $head = $list->head;
  my $ret_id;
  
  do {
    $ret_id = $head->name if $head->name =~ /^(chr)?$chr_id$/ && $head->size; # Check we get values back for seq region. Maybe need to add 'chr' 
  } while (!$ret_id && ($head = $head->next));
  
  warn " *** could not find region $chr_id in BigWig file" unless $ret_id;
  
  return $ret_id;
}

sub fetch_extended_summary_array {
  my ($self, $chr_id, $start, $end, $bins, $has_chrs) = @_;

  my $bw = $self->bigwig_open;
  warn "Failed to open BigWig file" . $self->url unless $bw;
  return [] unless $bw;
  
  #  Maybe need to add 'chr' (only try if species has chromosomes)
  my $seq_id = $has_chrs ? $self->munge_chr_id($chr_id) : $chr_id;
  return [] if !defined($seq_id);

# Remember this method takes half-open coords (subtract 1 from start)
  my $summary_e = $bw->bigWigSummaryArrayExtended("$seq_id",$start-1,$end,$bins);

  if ($DEBUG) {
    warn " *** fetch extended summary: $chr_id:$start-$end : found ", scalar(@$summary_e), " summary points\n";
  }
  
  return $summary_e;
}

1;
