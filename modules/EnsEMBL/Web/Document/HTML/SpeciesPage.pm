=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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
use EnsEMBL::Web::Utils::FormatText qw(glossary_helptip);

use base qw(EnsEMBL::Web::Document::HTML);

sub get_pre_species { return $_[0]->hub->species_defs->get_config('MULTI', 'PRE_SPECIES'); } # MOBILE: overwritten in the mobile site so that pre species are not shown

sub render {
  my ($self, $request) = @_;

  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $version       = $species_defs->ENSEMBL_VERSION;
  my $sitename      = $species_defs->ENSEMBL_SITETYPE;
  my $static_server = $species_defs->ENSEMBL_STATIC_SERVER;

  ## Get current Ensembl species
  my @valid_species = $species_defs->valid_species;
  my %species;

  foreach my $sp (@valid_species) {
    next if ($species_defs->get_config($sp, 'STRAIN_COLLECTION') 
              && $species_defs->get_config($sp, 'SPECIES_STRAIN') !~ /reference/);
    (my $genebuild = $hub->species_defs->get_config($sp, 'GENEBUILD_METHOD')) =~ s/_/ /g;
    my $genebuild_helptip = glossary_helptip($hub, ucfirst $genebuild);
    my $info    = {
        'dir'         => $sp,
        'common'      => $species_defs->get_config($sp, 'SPECIES_COMMON_NAME'),
        'status'      => 'live',
        'sci_name'    => $species_defs->get_config($sp, 'SPECIES_SCIENTIFIC_NAME'),
        'assembly'    => $species_defs->get_config($sp, 'ASSEMBLY_NAME'),
        'accession'   => $species_defs->get_config($sp, 'ASSEMBLY_ACCESSION'),
        'genebuild'   => $genebuild_helptip,
        'taxon_id'    => $species_defs->get_config($sp, 'TAXONOMY_ID'),
        'variation'   => $species_defs->get_config($sp,'databases')->{'DATABASE_VARIATION'},
        'regulation'  => $species_defs->get_config($sp,'databases')->{'DATABASE_FUNCGEN'},
    };
    $species{$sp} = $info;
  }

  if ($sitename !~ /Archive/) {
    ## Add in pre species
    my $pre_species = $self->get_pre_species();
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
            'accession'     => '-',
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
  }

  ## Display all the species in data table
  my $html = "<h3>$sitename Species</h3>";

  if ($species_defs->ENSEMBL_SERVERNAME eq 'grch37.ensembl.org') {
    ## Hardcode this because the version is actually updated when the site is upgraded
    $html .= qq(<div class="info-box"><p>N.B. The table below shows only those species that were included in release 75 - for an up-to-date list, please see our main site at <a href="http://www.ensembl.org/">www.ensembl.org</a>.</p></div>);
  }
  elsif ($sitename =~ /Archive/) {
    $html .= qq(<div class="info-box"><p>N.B. The table below shows only those species that were included in release $version - for an up-to-date list, please see our main site at <a href="http://www.ensembl.org/">www.ensembl.org</a>.</p></div>);
  }
  elsif ($hub->species_defs->multidb->{'DATABASE_ARCHIVE'}{'NAME'}) {
    $html .= '<p>Note: to find out which species were in previous releases, please see the <a href="/info/website/archives/assembly.html">table of assemblies</a></p>';
  }
  $html .= '<div class="js_panel" id="species-table">
      <input type="hidden" class="panel_type" value="Content">';

  my $columns = $self->table_columns();
  my $table = EnsEMBL::Web::Document::Table->new($columns, [], { data_table => 1, exportable => 1 });
  $table->code        = 'SpeciesTable::99';
  
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
    my $img_url = '/';
    if ($info->{'status'} eq 'pre') {
      $image_fade = 'opacity:0.7';
      $sp_link    = sprintf('<a href="http://pre.ensembl.org/%s" rel="external" class="bigtext pre_species">%s</a><br />(Pre)', $dir, $common);
      $img_url    = 'http://pre.ensembl.org/';
      $pre_link   = sprintf('<a href="http://pre.ensembl.org/%s" rel="external">%s</a>', $dir, $info->{'pre_assembly'});
    }
    else {
      $sp_link    = sprintf('<a href="/%s" class="bigtext">%s</a>', $dir, $common);
      $pre_link   = '-';
    }
    $table->add_row({
        'common' => sprintf('<a href="%s%s/"><img src="/i/species/48/%s.png" alt="%s" style="float:left;padding-right:4px;%s" /></a>%s',
                        $img_url, $dir,  $dir, $common, $image_fade, $sp_link),
      'species'     => '<i>'.$name.'</i>',
      'taxon_id'    => $info->{'taxon_id'},
      'assembly'    => $info->{'assembly'},
      'accession'   => $info->{'accession'} || '-',
      'genebuild'   => $info->{'genebuild'} || '-',
      'variation'   => $info->{'variation'} ? 'Y' : '-',
      'regulation'  => $info->{'regulation'} ? 'Y' : '-',
      'pre'         => $pre_link,
    });

# if a species is both pre and ensembl we are adding a new row for the pre assembly    
    if ($info->{'status'} eq 'both') {
      $table->add_row({
          'common' => sprintf('<a href="http://pre.ensembl.org/%s"><img src="/i/species/48/%1$s.png" alt="%s" style="float:left;padding-right:4px;opacity:0.7" /></a><a href="http://pre.ensembl.org/%1$s" rel="external" class="bigtext pre_species">%2$s</a><br />(Pre)', $dir, $common),
          'species'     => '<i>'.$name.'</i>',
          'taxon_id'    => $info->{'taxon_id'},
          'assembly'    => '-',
          'accession'   => '-',
          'genebuild'   => '-',
          'variation'   => '-',
          'regulation'  => '-',
          'pre'         => sprintf('<a href="http://pre.ensembl.org/%s" rel="external">%s</a>', $dir, $info->{'pre_assembly'}),
      });
    } 
  }
  $html .= $table->render;
  $html .= '</div>';
  return $html;  
}

# Overwritten in mobile plugins to hide some columns
# Return array of columns
sub table_columns {
  my $self = shift;

  my $columns = [
      { key => 'common',      title => 'Common name',     width => '40%', align => 'left', sort => 'html'   },
      { key => 'species',     title => 'Scientific name', width => '25%', align => 'left', sort => 'string' },
      { key => 'taxon_id',    title => 'Taxon ID',        width => '10%', align => 'left', sort => 'numeric' },
      { key => 'assembly',    title => 'Ensembl Assembly',width => '10%', align => 'left' },
      { key => 'accession',   title => 'Accession',       width => '10%', align => 'left' },
      { key => 'genebuild',   title => 'Genebuild Method', width => '10%', align => 'left' },
      { key => 'variation',   title => 'Variation database',  width => '5%', align => 'center', sort => 'string' },
      { key => 'regulation',  title => 'Regulation database', width => '5%', align => 'center', sort => 'string' },
  ];
  if ($self->hub->species_defs->ENSEMBL_SITETYPE !~ /Archive/) {
    push @$columns, { key => 'pre', title => 'Pre assembly', width => '5%', align => 'left' };
  }

  return $columns;
}

1;
