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

package EnsEMBL::Web::Factory::Gene;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Factory);

sub canLazy { return 1; }
sub createObjectsInternal {
  my $self = shift;

  return undef if $self->param('family');
  my $db = $self->param('db') || 'core';
     $db = 'otherfeatures' if $db eq 'est';
  my $db_adaptor = $self->database($db);
  return undef unless $db_adaptor;
  my $adaptor = $db_adaptor->get_GeneAdaptor;
  my $gene = $adaptor->fetch_by_stable_id($self->param('g'));
  return undef unless $gene;
  return $self->new_object('Gene', $gene, $self->__data);
}

sub createObjects { 
  my $self = shift;
  my $gene = shift;
  my ($identifier, $id, $param);
  
  my $db = $self->param('db') || 'core'; 
     $db = 'otherfeatures' if $db eq 'est';
  
  my $db_adaptor = $self->database($db);
  
  return $self->problem('fatal', 'Database Error', $self->_help("Could not connect to the $db database.")) unless $db_adaptor; 
  
  # Mapping of supported URL parameters to function calls on GeneAdaptor which should get a Gene for those parameters
  # Ordered by most likely parameter to appear in the URL
  my @params = (
    [ [qw(g gene           )], [qw(fetch_by_stable_id fetch_by_transcript_stable_id fetch_by_translation_stable_id)],1 ],
    [ [qw(t transcript     )], [qw(fetch_by_transcript_stable_id fetch_by_translation_stable_id                   )],0 ],
    [ [qw(p peptide protein)], [qw(fetch_by_translation_stable_id fetch_by_transcript_stable_id                   )],0 ],
    [ [qw(exon             )], [qw(fetch_by_exon_stable_id                                                        )],0 ],
    [ [qw(anchor1          )], [qw(fetch_by_stable_id fetch_by_transcript_stable_id fetch_by_translation_stable_id)],0 ],
  );
  
  if (!$gene) {
    my $adaptor = $db_adaptor->get_GeneAdaptor;
    
    # Loop through the parameters and the function calls, trying to find a Gene
    my $dodgy;
    foreach my $p (@params) {
      foreach (@{$p->[0]}) {
        if ($id = $self->param($_)) {
          (my $t  = $id) =~ s/^(\S+)\.\d*/$1/g;                                  # Strip versions
          (my $t2 = $id) =~ s/^(\S+?)(\d+)(\.\d*)?/$1 . sprintf('%011d', $2)/eg; # Make sure we've got eleven digits
          

          my $proposed;
          foreach my $fetch_call (@{$p->[1]}) {
            eval { $proposed = $adaptor->$fetch_call($id); };
            last if $proposed;
            eval { $proposed = $adaptor->$fetch_call($t2); };
            last if $proposed;
            eval { $proposed = $adaptor->$fetch_call($t);  };
            last if $proposed;
          }
          my $accept = 0;
          if(!$gene) {
            $accept = 1;
          } elsif($proposed and $dodgy) {
            if($proposed->stable_id eq $gene->stable_id) {
              #warn "Had to disambiguate genes with same stableid\n";
              $accept = 1;
            }
          }
          if($accept) {
            # First candidate
            $gene = $proposed;
            $param      = $_;
            $identifier = $id;
            $dodgy = $p->[2];
          }

          last;
        }
      }
      
      last if $gene and not $dodgy;
    }
    
    # Check if there is a family parameter
    if (!$gene && ($id = $self->param('family'))) {
      my $compara_db = $self->database('compara');
      
      if ($compara_db) {
        my $fa = $compara_db->get_FamilyAdaptor;
        $gene  = $fa->fetch_by_stable_id($id) if $fa;
        
        if ($gene) {
          $param      = 'family';
          $identifier = $id;
        }
      }
    }
    
    $gene ||= $self->_archive($param);                    # Check if this is an ArchiveStableId
    $gene ||= $self->_known_feature('Gene', $param, 'g'); # Last check to see if a feature can be found for the parameters supplied
  }
 
  my $out; 
  if ($gene) {
    $out = $self->new_object('Gene', $gene, $self->__data);
    $self->DataObjects($out);
    $self->generate_object('Location', $gene->feature_Slice) if $gene->can('feature_Slice'); # Generate a location from the gene. Won't be called if $gene is an ArchiveStableId object
    
    my $transcript;
    
    if ($gene->can('get_all_Transcripts')) { # will be false for families
      my @transcripts = @{$gene->get_all_Transcripts};
      
      # Mapping of supported URL parameters to functions used to find the relevant transcript
      my %get_transcript = (
        t    => sub { return [ grep $_->stable_id eq $_[1] || $_->external_name   eq $_[1], @{$_[0]} ]->[0]; },
        p    => sub { return [ grep $_->translation && $_->translation->stable_id eq $_[1], @{$_[0]} ]->[0]; },
        exon => sub { for (@{$_[0]}) { return $_ if grep $_->stable_id eq $_[1], @{$_->get_all_Exons}; }     }
      );
      
      $get_transcript{'protein'}    = $get_transcript{'peptide'} = $get_transcript{'p'};
      $get_transcript{'transcript'} = $get_transcript{'t'};
      
      # If the gene has a single transcript, or a transcript can be found based on the URL parameter (see functions in %get_transcript above),
      # we need to generate a transcript object for the top tabs
      $transcript = scalar @transcripts == 1 ? $transcripts[0] : exists $get_transcript{$param} ? $get_transcript{$param}(\@transcripts, $identifier) : undef;
      
      # If we haven't got a transcript yet, loop through the @params mapping, trying to find a transcript.
      # We can get to this point if $param is g or gene
      if (!$transcript && !$get_transcript{$param}) {
        shift @params; # $param is g or gene, so we don't care about this element in the @params array
        
        foreach (map @{$_->[0]}, @params) {
          if (exists $get_transcript{$_} && ($id = $self->param($_))) {
            $transcript = $get_transcript{$_}(\@transcripts, $id);
            last if $transcript;
          }
        }
      }
      
      my @transcript_params = grep s/^t(\d+)$/$1/, $self->param;
      
      if (scalar @transcript_params) {
        my %transcript_ids = map { $_->stable_id => 1 } @transcripts;
        $self->delete_param("t$_") for grep !$transcript_ids{$self->param("t$_")}, @transcript_params;
      }
    }
    
    # Generate the transcript object for the top tabs, and set the t parameter for the URL
    # If there's no transcript, delete any existing t parameter, because it does not map to this gene
    if ($transcript) {
      $self->generate_object('Transcript', $transcript);
      $self->param('t', $transcript->stable_id);
    } else {
      $self->delete_param('t');
    }
    
    $self->param('g', $gene->stable_id) unless $param eq 'family';
    $self->delete_param('gene');
  }
  return $out;
}

sub _help {
  my ($self, $string) = @_;

  my %sample    = %{$self->species_defs->SAMPLE_DATA || {}};
  my $help_text = $string ? sprintf '<p>%s</p>', encode_entities($string) : '';
  my $url       = $self->hub->url({ __clear => 1, action => 'Summary', g => $sample{'GENE_PARAM'} });
  
  $help_text .= sprintf('
  <p>
    This view requires a gene, transcript or protein identifier in the URL. For example:
  </p>
  <div class="left-margin bottom-margin word-wrap"><a href="%s">%s</a></div>',
    encode_entities($url),
    encode_entities($self->species_defs->ENSEMBL_BASE_URL . $url)
  );

  return $help_text;
}

1;
