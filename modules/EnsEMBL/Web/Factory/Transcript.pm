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

package EnsEMBL::Web::Factory::Transcript;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Fake;

use base qw(EnsEMBL::Web::Factory);

sub canLazy { return 1; }
sub createObjectsInternal {
  my $self = shift;
  my $db = $self->param('db') || 'core';
  $db = 'otherfeatures' if $db eq 'est';
  my $db_adaptor = $self->database($db);
  return undef unless $db_adaptor;
  my $adaptor = $db_adaptor->get_TranscriptAdaptor;
  return undef unless $adaptor;
  my $transcript = $adaptor->fetch_by_stable_id($self->param('t'));
  if ($transcript) {
    return $self->new_object('Transcript', $transcript, $self->__data);
  }
  else {
    ## Fall back to standard method if stable ID doesn't return
    ## a transcript, e.g. if it's a prediction transcript
    $self->createObjects;
  }
}

sub createObjects {   
  my $self       = shift;
  my $transcript = shift;
  my ($identifier, $param, $new_factory_type);
  
  my $db = $self->param('db') || 'core';
     $db = 'otherfeatures' if $db eq 'est';
  my $db_adaptor = $self->database($db);	
  
  return $self->problem('fatal', 'Database Error', $self->_help("Could not connect to the $db database.")) unless $db_adaptor; 
  
  if (!$transcript) {
    $new_factory_type = 'Gene';
    
    # Mapping of supported URL parameters to function calls on TranscriptAdaptor and PredictionTranscriptAdaptor which should get a Transcript or PredictionTranscript for those parameters
    # Ordered by most likely parameter to appear in the URL
    my @params = (
      [ [qw(t transcript     )], [qw(fetch_by_stable_id fetch_by_translation_stable_id)] ],
      [ [qw(pt               )], [qw(fetch_by_stable_id                               )] ],
      [ [qw(p peptide protein)], [qw(fetch_by_translation_stable_id fetch_by_stable_id)] ],
      [ [qw(exon             )], [qw(fetch_all_by_exon_stable_id                      )] ],
      [ [qw(anchor1          )], [qw(fetch_by_stable_id fetch_by_translation_stable_id)] ],
    );
    
    # Loop through the parameters and the function calls, trying to find a Transcript or PredictionTranscript
    foreach my $p (@params) {
      foreach (@{$p->[0]}) {
        if ($identifier = $self->param($_)) {
          (my $t  = $identifier) =~ s/^(\S+)\.\d*/$1/g;                                  # Strip versions
          (my $t2 = $identifier) =~ s/^(\S+?)(\d+)(\.\d*)?/$1 . sprintf('%011d', $2)/eg; # Make sure we've got eleven digits
          
          $param = $_;
          
          @{$p->[1]} = reverse @{$p->[1]} if $_ eq 'anchor1' && $self->param('type1') eq 'peptide';
          $new_factory_type = 'Location'  if $_ eq 'pt';
          
          foreach my $adapt_class ('TranscriptAdaptor', 'PredictionTranscriptAdaptor') {
            my $func    = "get_$adapt_class";
            my $adaptor = $db_adaptor->$func;
        
            foreach my $fetch_call (@{$p->[1]}) {
              eval { $transcript = $adaptor->$fetch_call($identifier); };
              last if $transcript;
              eval { $transcript = $adaptor->$fetch_call($t2); };
              last if $transcript;
              eval { $transcript = $adaptor->$fetch_call($t);  };
              last if $transcript;
            }
            
            last if $transcript;
          }
          
          last;
        }
      }
      
      last if $transcript;
    }
    
    # Check if there is a domain parameter
    if (!$transcript && ($identifier = $self->param('domain'))) {
      my $sth = $db_adaptor->dbc->db_handle->prepare('select i.interpro_ac, x.display_label, x.description from interpro as i left join xref as x on i.interpro_ac = x.dbprimary_acc where i.interpro_ac = ?');
      $sth->execute($identifier);
      my ($t, $n, $d) = $sth->fetchrow;
      
      $transcript = EnsEMBL::Web::Fake->new({ view => 'Domains/Genes', type => 'Interpro Domain', id => $t, name => $n, description => $d, adaptor => $db_adaptor->get_GeneAdaptor }) if $t;
      $new_factory_type = undef;
    }
    
    $transcript = $transcript->[0] if ref $transcript eq 'ARRAY'; # if fetch_call is type 'fetch_all', take first object
    
    if (!$transcript) {
      $transcript = $self->_archive($param); # Check if this is an ArchiveStableId
      $new_factory_type = undef if $transcript;
    }
    
    $transcript ||= $self->_known_feature('Transcript', $param, 't'); # Last check to see if a feature can be found for the parameters supplied
  }

  my $out;  
  if ($transcript) {
    $out = $self->new_object('Transcript', $transcript, $self->__data);
    $self->DataObjects($out);
    
    if ($new_factory_type) {
      $self->generate_object('Location', $transcript->feature_Slice); # Generate a location from the transcript
      
      # Generate the transcript's gene unless it is a PredictionTranscript
      if ($new_factory_type eq 'Gene') {
        my $gene = $db_adaptor->get_GeneAdaptor->fetch_by_transcript_stable_id($transcript->stable_id);
        $self->param('g', $gene->stable_id) if $gene && $self->generate_object('Gene', $gene) && $self->param('g') ne $gene->stable_id;
      }
    }
    
    $self->param('t', $transcript->stable_id) unless $transcript->isa('Bio::EnsEMBL::PredictionTranscript');
    $self->delete_param($_) for qw(transcript peptide protein);
  }
  return $out;
}

sub _help {
  my ($self, $string) = @_;

  my %sample    = %{$self->species_defs->SAMPLE_DATA || {}};
  my $help_text = $string ? sprintf '<p>%s</p>', encode_entities($string) : '';
  my $url       = $self->hub->url({ __clear => 1, action => 'Summary', t => $sample{'TRANSCRIPT_PARAM'} });
  
  $help_text .= sprintf('
    <p>
      This view requires a transcript or protein identifier in the URL. For example:
    </p>
    <div class="left-margin bottom-margin word-wrap"><a href="%s">%s</a></div>',
    encode_entities($url),
    encode_entities($self->species_defs->ENSEMBL_BASE_URL . $url)
  );
  
  return $help_text;
}

1;
