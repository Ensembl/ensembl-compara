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

########################################################################################
#
# DEPRECATED MODULE - PLEASE SEE ensembl-io/modules/Bio/EnsEMBL/IO/Adaptor/BigWigAdaptor
#
########################################################################################


use Data::Dumper;
use Bio::DB::BigFile;
use Bio::DB::BigFile::Constants;
my $DEBUG = 0;


sub new {
  my ($class, $url) = @_;
 
  warn "######## DEPRECATED MODULE";
  warn "### This module will be removed in release 82 - please use Bio::EnsEMBL::IO::Adaptor::BigWigAdaptor instead";
 
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

sub fetch_summary_array {
  my ($self, $chr_id, $start, $end, $bins, $has_chrs, $mode) = @_;

  $mode ||= 0;
  my $bw = $self->bigwig_open;
  warn "Failed to open BigWig file" . $self->url unless $bw;
  return [] unless $bw;

  #  Maybe need to add 'chr' (only try if species has chromosomes)
  my $seq_id = $has_chrs ? $self->munge_chr_id($chr_id) : $chr_id;
  return [] if !defined($seq_id);

# Remember this method takes half-open coords (subtract 1 from start)
  my $summary = $bw->bigWigSummaryArray("$seq_id",$start-1,$end,$mode,$bins);

  if ($DEBUG) {
    warn " *** fetch extended summary: $chr_id:$start-$end : found ", scalar(@$summary), " summary points\n";
  }

  return $summary;
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

sub fetch_scores_by_chromosome {
### Get data across a single chromosome or the whole genome
### @param chromosomes ArrayRef - usually just one chromosome (undef if whole karyotype is wanted)
### @param bins Integer - number of bins to divide data into
### @param bin_size Integer - default size of bin in base pairs 
  my ($self, $chromosomes, $bins, $bin_size) = @_;
  my (%data, $max);
  return ({}, undef) unless $self->check;

  my $bw = $self->bigwig_open;
  if ($bw) {
    ## If we're on a single-chromosome page, we want to filter the BigWig data
    my %chr_check;
    foreach (@{$chromosomes||[]}) {
      $chr_check{$_} = 1;
      ## Also convert our chromosome names into UCSC equivalents
      my $chr_name = 'chr'.$_;
      $chr_name = 'chrM' if $chr_name eq 'chrMT';
      $chr_check{$chr_name} = 1;
    }
    my $chrs = $bw->chromList;
    my $chr = $chrs->head;
    while ($chr) {
      if (!$chromosomes || $chr_check{$chr->name}) {
        my $stats = $bw->bigWigSummaryArrayExtended($chr->name, 1, $chr->size, $bins);
        my @scores;

        foreach (@$stats) {
          my $mean    = $_->{'validCount'}
                          ? sprintf('%.2f', ($_->{'sumData'} / $_->{'validCount'}))
                          : 0;

          push @scores, $mean;

          ## Get the maximum via each bin rather than for the entire dataset, 
          ## so we can scale nicely on single-chromosome pages
          my $bin_max = sprintf('%.2f', $_->{'maxVal'});
          $max = $bin_max if $max < $bin_max;
        }

        ## Translate chromosome name back from its UCSC equivalent
        (my $chr_name = $chr->name) =~ s/chr//;
        $chr_name = 'MT' if $chr_name eq 'M';
        $data{$chr_name} = \@scores;

      }
      $chr = $chr->next;
    }
  }
  return (\%data, $max);
}

1;
