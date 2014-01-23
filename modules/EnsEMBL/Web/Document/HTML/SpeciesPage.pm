=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::HTML::SpeciesPage;

### Renders the content of the  "Find a species page" linked to from the SpeciesList module

use strict;

use EnsEMBL::Web::Document::Table;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my ($self, $request) = @_;

  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $sitename      = $species_defs->ENSEMBL_SITETYPE;
  my $static_server = $species_defs->ENSEMBL_STATIC_SERVER;

  ## Get current Ensembl species
  my @valid_species = $species_defs->valid_species;
  my $species_check;
  foreach my $sp (@valid_species) {
    $species_check->{$sp}++;
  }

  my %species;
  foreach my $sp (@valid_species) {
    my $info    = {
        'dir'         => $sp,
        'common'      => $species_defs->get_config($sp, 'SPECIES_COMMON_NAME'),
        'status'      => 'live',
        'sci_name'    => $species_defs->get_config($sp, 'SPECIES_SCIENTIFIC_NAME'),
        'assembly'    => $species_defs->get_config($sp, 'ASSEMBLY_NAME'),
        'taxon_id'    => $species_defs->get_config($sp, 'TAXONOMY_ID'),
        'variation'   => $species_defs->get_config($sp,'databases')->{'DATABASE_VARIATION'},
        'regulation'  => $species_defs->get_config($sp,'databases')->{'DATABASE_FUNCGEN'},
    };
    $species{$sp} = $info;
  }

  ## Add in pre species
  my $pre_species = $species_defs->get_config('MULTI', 'PRE_SPECIES');
  if ($pre_species) {
    while (my ($bioname, $array) = each (%$pre_species)) {
      my ($common, $assembly, $taxon_id) = @$array;
      $common =~ s/_/ /;
      my $status = $species{$bioname} ? 'both' : 'pre';
      my $info;
      if ($status eq 'pre') {
        ## This is a bit of a fudge, but we have only basic config atm
        (my $sci_name = $bioname) =~ s/_/ /g;
        $info = {
          'dir'           => $bioname,
          'common'        => $common,
          'sci_name'      => $sci_name,
          'status'        => $status,
          'assembly'      => '-',
          'pre_assembly'  => $assembly,
          'taxon_id'      => $taxon_id,
        };
      }
      else {
        ## Don't overwrite existing meta info!
        $info = $species{$bioname};
        $info->{'pre_assembly'} = $assembly;
      }
      $info->{'status'} = $status;
      $species{$bioname} = $info;
    }
  }

  ## Display all the species in data table
  my $html = '<h3>Current Ensembl Species</h3>
<p>Note: to find out which species were in previous releases, please see the <a href="/info/website/archives/assembly.html">table of assemblies</a></p>
<div class="js_panel" id="species-table">
      <input type="hidden" class="panel_type" value="Content">';

  my $table = EnsEMBL::Web::Document::Table->new([
      { key => 'common',      title => 'Common name',     width => '40%', align => 'left', sort => 'string' },
      { key => 'species',     title => 'Scientific name', width => '25%', align => 'left', sort => 'string' },
      { key => 'taxon_id',    title => 'Taxon ID',        width => '10%', align => 'left', sort => 'integer' },
      { key => 'assembly',    title => 'Assembly',        width => '10%', align => 'left' },
      { key => 'variation',   title => 'Variation database',  width => '5%', align => 'center', sort => 'string' },
      { key => 'regulation',  title => 'Regulation database', width => '5%', align => 'center', sort => 'string' },
      { key => 'pre',         title => 'Pre assembly',    width => '5%', align => 'left' },
  ], [], { data_table => 1, exportable => 1 });
  
  $table->filename = 'Species';
  
  foreach my $info (sort {$a->{'common'} cmp $b->{'common'}} values %species) {
    next unless $info;
    my $dir       = $info->{'dir'};
    next unless $dir;
    my $common    = $info->{'common'};
    my $name      = $info->{'sci_name'};
    if ($common eq $name) {
      $common =~ s/([A-Z])([a-z]+)\s+([a-z]+)/$1. $3/;
    }

    my ($sp_link, $pre_link, $image_fade);
    if ($info->{'status'} eq 'pre') {
      $image_fade = 'opacity:0.7';
      $sp_link    = sprintf('<span class="bigtext">%s</span><br />(Pre only)', $common);
      $pre_link   = sprintf('<a href="http://pre.ensembl.org/%s">%s</a>', $dir, $info->{'pre_assembly'});
    }
    elsif ($info->{'status'} eq 'both') {
      $sp_link    = sprintf('<a href="/%s" class="bigtext">%s</a>', $dir, $common);
      $pre_link   = sprintf('<a href="http://pre.ensembl.org/%s">%s</a>', $dir, $info->{'pre_assembly'});
    }
    else {
      $sp_link    = sprintf('<a href="/%s" class="bigtext">%s</a>', $dir, $common);
      $pre_link   = '-';
    }
    $table->add_row({
      'common' => sprintf('<a href="/%s/"><img src="/i/species/48/%s.png" alt="%s" style="float:left;padding-right:4px;%s" /></a>%s',
                        $dir, $dir, $common, $image_fade, $sp_link),
      'species'     => '<i>'.$name.'</i>',
      'taxon_id'    => $info->{'taxon_id'},
      'assembly'    => $info->{'assembly'},
      'variation'   => $info->{'variation'} ? 'Y' : '-',
      'regulation'  => $info->{'regulation'} ? 'Y' : '-',
      'pre'         => $pre_link,
    });

  }
  $html .= $table->render;
  $html .= '</div>';
  return $html;  
}

1;
