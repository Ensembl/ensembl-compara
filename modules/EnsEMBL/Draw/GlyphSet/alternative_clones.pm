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

package EnsEMBL::Draw::GlyphSet::alternative_clones;

### Retrieve clones from e! or Vega using DAS and compare with those used

use strict;

use Bio::EnsEMBL::SimpleFeature;
use Bio::EnsEMBL::ExternalData::DAS::Coordinator;
use Bio::EnsEMBL::ExternalData::DAS::Source;
use Bio::EnsEMBL::ExternalData::DAS::CoordSystem;

use base qw(EnsEMBL::Draw::GlyphSet_simple);

sub label_overlay { return 1; }

sub my_label {
  my $self = shift;
  return $self->my_config('other') . " clones";
}

sub features {
  my $self       = shift;
  my $slice      = $self->{'container'};
  my $das_source = $self->my_config('das_source');
  my $conf       = $self->species_defs->$das_source;
  my $res;
  return unless $conf;
  my $source = Bio::EnsEMBL::ExternalData::DAS::Source->new(
    -DSN           => $conf->{'dsn'},
    -URL           => $conf->{'url'},
    -LABEL         => $conf->{'label'},
    -COORDS        => [ Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -NAME => 'clone') ],
  );
  my $c = Bio::EnsEMBL::ExternalData::DAS::Coordinator->new([ $source ]);
  my $csa = $self->{'config'}->hub->get_adaptor('get_CoordSystemAdaptor');
  my @coord_systems;
  foreach my $cs ( @{ $csa->fetch_all() } ) {
    push @coord_systems, $cs->name if ($cs->name ne 'chromosome')
  }

  # retrieve from each clone on the slice
  my $found = 0;
  foreach my $projection_type (@coord_systems) {
    next if $found;
    foreach my $segment (@{ $slice->project($projection_type) }){
      my $clone = $segment->to_Slice->seq_region_name;
      my ($clone_name,$clone_version) = split(/\./, $clone);
#      warn "looking for $ clone_name,$clone_version";
#      warn "looking at this part of the clone ",$segment->to_Slice->start;
      my $struct = $c->fetch_Features( $segment->to_Slice );
      foreach my $logic_name ( keys %{ $struct } ) {
        foreach my $proj_segment ( keys %{ $struct->{$logic_name}{'features'} } ) {
          foreach my $proj (@{$struct->{$logic_name}{'features'}{$proj_segment}{'objects'}}) {
#            warn "for logic name $logic_name, checking $projection_type against ".$proj->type_label;
            if ($proj->type_label eq $projection_type) {
              $found = 1;
              my ($proj_name, $proj_version) = split(/\./, $proj->display_id);
#              warn "  found $proj_name,$proj_version";
#              warn "from start = ",$proj->slice->start;
              if ($clone_name eq $proj_name) {
                my $f = Bio::EnsEMBL::SimpleFeature->new(
                  -display_label  => $proj->display_id.':'.$proj->slice->start.'-'.$proj->slice->end,
                  -start          => $segment->from_start,
                  -end            => $segment->from_end,
                  -strand         => $segment->to_Slice->strand,
                );
                # is the clone found by DAS newer/older/same as the source clone ?
                if ($proj_version > $clone_version) {
                  $f->{'status'} = 'newer_clone';
                } elsif ($proj_version == $clone_version){
                  $f->{'status'} = 'same_clone';
                } else {
                  $f->{'status'} = 'older_clone';
                }
                push(@{$res}, $f);
              }
            }
          }
        }
      }
    }
  }
  return $res;
}

sub colour_key {
  my ($self, $f) = @_;
  return ($f->{'status'});
}

sub href {
  my ($self, $f) = @_;
  my ($clone_id) = split /\./ ,  $f->display_id;
  my $status = $f->{'status'};
  my ($loc) = split (/\./, $f->display_id);
  $loc = $f->display_id;
  my $url = $self->_url({
    'jump_loc' => $loc,
    'status'   => $f->{'status'},
  });
  return $url;
}

sub feature_label {
  my ($self, $f) = @_;
  return $f->display_id;
}

1;
