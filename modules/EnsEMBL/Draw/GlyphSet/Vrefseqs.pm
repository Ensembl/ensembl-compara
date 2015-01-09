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

package EnsEMBL::Draw::GlyphSet::Vrefseqs;

### Draws vertical density track on single chromosome - no longer used?

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
    my ($self) = @_;
    my $Config = $self->{'config'};
    my $chr      = $self->{'container'}->{'chr'};

    my $sa = $self->{'container'}->{'sa'};
    my $da = $self->{'container'}->{'da'};

    my $chr_slice = $sa->fetch_by_region('chromosome', $chr);
    my $refseqs   = $da->fetch_Featureset_by_Slice
      ($chr_slice, 'refseqs',150,1); 

    return unless $refseqs->size(); # Return nothing if their is no data
    
    my $refseqs_col = $Config->get( 'Vrefseqs','col' );
	
    $refseqs->scale_to_fit( $Config->get( 'Vrefseqs', 'width' ) );
    $refseqs->stretch(0);
    my @refseqs = $refseqs->get_binvalues();

    foreach (@refseqs){
      $self->push($self->Rect({
        'x'            => $_->{'chromosomestart'},
        'y'            => 0,
        'width'        => $_->{'chromosomeend'}-$_->{'chromosomestart'},
        'height'       => $_->{'scaledvalue'},
        'bordercolour' => $refseqs_col,
        'absolutey'    => 1,
        'href'         => $self->_url({ type => 'Location', action => 'View', r => "$chr:$_->{'chromosomestart'}-$_->{'chromosomeend'}" })
      }));
    }
}

1;
