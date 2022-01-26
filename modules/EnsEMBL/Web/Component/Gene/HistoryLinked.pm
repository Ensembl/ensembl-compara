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

package EnsEMBL::Web::Component::Gene::HistoryLinked;

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub caption {
  return 'Associated archived IDs for this stable ID version';
}

sub content_protein {
  my $self = shift;
  $self->content(1);
}

sub content {
  my $self    = shift;
  my $protein = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $archive_object;

 if ($protein == 1) {
    my $transcript = $object->transcript;
    my $translation_object;
    
    if ($transcript->isa('Bio::EnsEMBL::ArchiveStableId') || $transcript->isa('EnsEMBL::Web::Fake')){
       my $p = $hub->param('p') || $hub->param('protein');    
       
       if (!$p) {                                                                 
         my $p_archive = shift @{$transcript->get_all_translation_archive_ids};
         $p = $p_archive->stable_id;
       }
       my $db          = $hub->param('db') || 'core';
       my $db_adaptor  = $hub->database($db);
       my $a           = $db_adaptor->get_ArchiveStableIdAdaptor;
       $archive_object = $a->fetch_by_stable_id($p);
    } else {
       $translation_object = $object->translation_object;
       $archive_object     = $translation_object->get_archive_object;
    }
  } else {    # retrieve archive object
    $archive_object = $object->get_archive_object;
  }

  return unless $archive_object;

  my $assoc = $self->get_assoc($archive_object);
  
  return '<p>No associated IDs found</p>' unless scalar @$assoc;

  my $table = $self->new_table([], [], { margin => '1em 0px' });
  
  $table->add_columns (      
    { key => 'release',     title => 'Release'    },
    { key => 'gene' ,       title => 'Gene'       },   
    { key => 'transcript',  title => 'Transcript' },
    { key => 'translation', title => 'Protein'    },  
  );  
  
  $table->add_row($_) for @$assoc;  

  return $table->render;
}

sub get_assoc {
  my ($self, $archive_object) = @_; 
  my @associated = @{$archive_object->get_all_associated_archived};
  
  return [] unless @associated;

  my @sorted = sort { $a->[0]->release <=> $b->[0]->release || $a->[0]->stable_id cmp $b->[0]->stable_id } @associated;

  my $last_release;
  my $last_gsi;
  my @a; 

  while (my $r = shift @sorted) {
    my %temp;
    my ($release, $gsi, $tsi, $tlsi, $pep_seq);

    # release
    if ($r->[0]->release == $last_release) {
      $release = undef;
    } else {
      $last_gsi = undef;
      $release = $r->[0]->release;
    }

    # gene
    if ($r->[0]->stable_id eq $last_gsi) {
      $gsi = undef;
    } else {
      $gsi = $self->idhistoryview_link('Gene', 'g', $r->[0]->stable_id);
    }

    # transcript
    $tsi = $self->idhistoryview_link('Transcript', 't', $r->[1]->version ?  $r->[1]->stable_id.".".$r->[1]->version : $r->[1]->stable_id);
    
    # translation
    if ($r->[2]) {
      $tlsi  = $self->idhistoryview_link('Transcript', 'p', $r->[2]->stable_id);
      $tlsi .= '<br />' . $self->get_formatted_pep_seq($r->[3], $r->[2]->stable_id);
    } else {
      $tlsi = 'none';
    }

    $last_release = $r->[0]->release;
    $last_gsi     = $r->[0]->stable_id;

    $temp{'release'}     = $release;
    $temp{'gene'}        = $gsi;
    $temp{'transcript'}  = $tsi;
    $temp{'translation'} = $tlsi;
    
    push @a, \%temp;
  }

  return \@a;
}


sub idhistoryview_link {
  my ($self, $type, $param, $stable_id) = @_;
  
  return undef unless $stable_id;
  
  my $hub        = $self->hub;
  my $url_params = { type => $type, action => 'Idhistory', $param => $stable_id, __clear => 1 };
  my $url        = $hub->url({ %$url_params, function => $param eq 'p' ? 'Protein' : undef });
  
  return qq{<a href="$url">$stable_id</a>};
}

sub get_formatted_pep_seq {
  my ($self, $seq, $stable_id) = @_;
  my $html;

  if ($seq) {
    $seq  =~ s#(.{1,60})#$1<br />#g;
    $html = "<kbd>$seq</kbd>";
  }

  return $html;
}


1;
