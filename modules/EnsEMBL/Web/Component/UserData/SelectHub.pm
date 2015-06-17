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

package EnsEMBL::Web::Component::UserData::SelectHub;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Document::Table;
use EnsEMBL::Web::DBSQL::ArchiveAdaptor;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Select Hub to Attach';
}

sub content {
  my $self          = shift;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;

  ## Get current Ensembl species
  my @valid_species = $species_defs->valid_species;
  my $current_species = $hub->species;
  my $current_assembly = $species_defs->ASSEMBLY_VERSION;

  my $datahubs = {};
  my (%this_assembly, %this_species, %other_species);
  my $imageconfig   = $hub->get_imageconfig('contigviewbottom');
  foreach my $sp (@valid_species) {
    ## This is all a bit hacky, but makes configuration of multi-species datahubs simpler
    my %sp_hubs = (%{$species_defs->get_config($sp, 'PUBLIC_DATAHUBS')||{}}, $species_defs->multiX('PUBLIC_MULTISPECIES_DATAHUBS'));

    ## Get hub information
    if (keys %sp_hubs) {
      while (my($key,$menu) = each (%sp_hubs)) {
        ## multiX returns a hash, not a hash ref, and Perl gets confused
        ## if you try to assign hashes and hashrefs to same variable
        my %multi = $species_defs->multiX($key);
        my %config = keys %multi ? %multi : %{$species_defs->get_config($sp, $key)||{}};
        next unless keys %config;
        my %assemblies;
        if ($config{'assemblies'}) {
          %assemblies = @{$config{'assemblies'}};
        }
        else {
          foreach (@{$config{'assembly'}}) {
            $assemblies{$_} = $sp;
          }
        }
        $config{'priority'} = 0 unless $config{'priority'};
        $datahubs->{$key} = {'menu' => $menu, %config};
        foreach my $assembly (sort { $assemblies{$a} cmp $assemblies{$b} || $a cmp $b } keys %assemblies) {
          my $sp = $assemblies{$assembly};
          if ($sp eq $current_species) {
            if ($assembly eq $current_assembly) {
              $this_assembly{$key} = 1;
            }
            else {
              $this_species{$key} = 1;
            }
          }
          else {
            $other_species{$key} = 1;
          }
          if ($datahubs->{$key}{'species'}) {
            push @{$datahubs->{$key}{'species'}}, {'dir' => $sp, 'common' => $species_defs->get_config($sp, 'SPECIES_COMMON_NAME'), 'assembly' => $assembly};
          }
          else {
            $datahubs->{$key}{'species'} = [{'dir' => $sp, 'common' => $species_defs->get_config($sp, 'SPECIES_COMMON_NAME'), 'assembly' => $assembly}];
          }
        }
      }
    }
  }

  my $html;

  my $link = $hub->url({'type' => 'UserData', 'action' => 'SelectFile'});
  $html .= $self->info_panel('Tip', qq(If you don't see the hub you are interested in listed here, you can <a href="$link" class="modal_link">manually attach any hub</a> for which you know the URL.));

  my @keys_1 = keys %this_assembly;
  my $table_1 = $self->create_table($datahubs, \@keys_1);
  $html .= '<h3>Hubs with data on the current species and assembly</h3>';
  if ($table_1) {
    $html .= '<p>Links for other species may go to archive sites</p>';
    $html .= $table_1;
  }
  else {
    $html .= '<p>Sorry, we have no listed hubs for this species and assembly</p>';
  }

  my @keys_2 = keys %this_species;
  my $table_2 = $self->create_table($datahubs, \@keys_2);
  $html .= '<h3>Hubs with data on the current species but older assemblies</h3>';
  if ($table_2) {
    $html .= '<p>Links may go to archive sites</p>';
    $html .= $table_2;
  }
  else {
    $html .= '<p>Sorry, we have no other listed hubs for this species</p>';
  }

  my @keys_3 = keys %other_species;
  my $table_3 = $self->create_table($datahubs, \@keys_3);
  $html .= '<h3>Hubs with data on other species</h3>';
  if ($table_3) {
    $html .= '<p>Links may go to archive sites</p>';
    $html .= $table_3;
  }
  else {
    $html .= '<p>Sorry, we have no other listed hubs</p>';
  }

  $html .= '</div>';
  return $html; 
}

sub create_table {
  my ($self, $datahubs, $keys) = @_;
  my $species_defs  = $self->hub->species_defs;
  my $adaptor       = EnsEMBL::Web::DBSQL::ArchiveAdaptor->new($self->hub);

  my $table = EnsEMBL::Web::Document::Table->new([
      { key => 'name',     title => 'Trackhub name', width => '30%', align => 'left', sort => 'html' },
      { key => 'description',    title => 'Description', width => '30%', align => 'left', sort => 'string' },
      { key => 'species',      title => 'Species and assembly', width => '40%', align => 'left', sort => 'html' },
  ], [], {});

  my @order = sort { $datahubs->{$b}->{'priority'} <=> $datahubs->{$a}->{'priority'}
                    || lc($datahubs->{$a}->{'name'}) cmp lc($datahubs->{$b}->{'name'})
                    } @$keys;

  my $row_count = 0;
  foreach my $key (@order) {
    my $hub_info = $datahubs->{$key};
    next unless keys %$hub_info;
    my $row = {
              'name'        => $hub_info->{'name'},
              'description' => $hub_info->{'description'},
              };
    $row_count++;
    my (@species_links, $species_html);
    foreach my $sp_info (@{$hub_info->{'species'}}) {
      my $species = $sp_info->{'dir'};

      if ($species_defs->multidb->{'DATABASE_ARCHIVE'}{'NAME'}) {
        ## Get best archive for older releases
        my $archive_version = $species_defs->ENSEMBL_VERSION;
        ## Spaces are problematic in ini file arrays
        (my $current_assembly = $species_defs->get_config($species, 'ASSEMBLY_VERSION')) =~ s/ /_/;
        if ($current_assembly =~ /$sp_info->{'assembly'}/i) {
          $sp_info->{'site'} = 'current';
        }
        else {
          if ($species eq 'Homo_sapiens' && $sp_info->{'assembly'} eq 'GRCh37') {
            $sp_info->{'site'} = 'http://grch37.ensembl.org';
          }
          else {
            my $archives = $adaptor->fetch_archives_by_species($species);
            foreach (reverse sort keys %$archives) {
              (my $assembly = $archives->{$_}{'assembly'}) =~ s/ /_/;
              if ($assembly =~ /$sp_info->{'assembly'}/i) {
                $archive_version = $_;
                $sp_info->{'site'} = sprintf('http://%s.archive.ensembl.org', $archives->{$_}{'archive'});
                last;
              }
            }
            $sp_info->{'site'} = '' if $archive_version < 75;
          }
        }
        ## Don't link back to archives with no/buggy datahub support!
      }
            

      my $location = $species_defs->get_config($species, 'SAMPLE_DATA')->{'LOCATION_PARAM'};
      if ($sp_info->{'site'}) {
        my $site = $sp_info->{'site'} eq 'current' ? '' : $sp_info->{'site'};
        my $link;
        $link = sprintf('%s/%s/Location/View?r=%s;contigviewbottom=url:%s;format=DATAHUB;menu=%s#modal_user_data',
                         $site, $sp_info->{'dir'}, $location,
                         $hub_info->{'url'}, $hub_info->{'menu'}, $hub_info->{'menu'}
                        );
        $species_html .= sprintf('<p><a href="%s"><img src="/i/species/16/%s.png" alt="%s" style="float:left;padding-right:4px" /></a> <a href="%s">%s (%s)</a></p>',
                                  $link, $sp_info->{'dir'}, $sp_info->{'common'},
                                  $link, $sp_info->{'common'}, $sp_info->{'assembly'},
                                );
      }
      else {
        $species_html .= sprintf('<p><img src="/i/species/16/%s.png" alt="%s" style="float:left;padding-right:4px" /> %s (%s)</p>',
                                $sp_info->{'dir'}, $sp_info->{'common'},
                                $sp_info->{'common'}, $sp_info->{'assembly'},
                                );
      }
    }
    $row->{'species'} = $species_html;
    $table->add_row($row);
    delete $datahubs->{$key};
  }
  return $row_count > 0 ? $table->render : undef;
}

1;
