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

package EnsEMBL::Draw::Utils::TextHelper;
use strict;

#########
# stinky GD helper object for fonts
#
sub new {
    my ($class, $transform) = @_;
    my $this = {
	'_scalex' => $transform->{'scalex'},
	'_scaley' => $transform->{'scaley'},
	'Tiny' => {
		'width'  => 5,
		'height' => 8,
	},
	'Small' => {
		'width'  => 6,
		'height' => 12,
	},
	'MediumBold' => {
		'width'  => 10, #7,
		'height' => 13,
	},
	'Large' => {
		'width'  => 11, #8,
		'height' => 16,
	},
	'Giant' => {
		'width'  => 13,
		'height' => 15,
	},
    };

    bless($this, $class);
    return $this;
}

#########
# basepair to pixel ratio for a specified font
# $scaling may be calculated from $Config->dimensions()[0] / $vc->length();
#
sub bp2px {
    my ($this, $fontname) = @_;
    my $scalex = $this->{'_scalex'} || 1;
    my $scaley = $this->{'_scaley'} || 1;
    return (int($this->{$fontname}->{'width'} * $scalex), int($this->{$fontname}->{'height'} * $scaley));
}

#########
# basepair to pixel ratio for a specified font
# $scaling may be calculated from $Config->dimensions()[0] / $vc->length();
#
sub px2bp {
    my ($this, $fontname) = @_;
    my $scalex = $this->{'_scalex'} || 1;
    my $scaley = $this->{'_scaley'} || 1;
    return (  $this->{$fontname}->{'width'} / $scalex, $this->{$fontname}->{'height'} / $scaley );
}

sub real_px2bp {
    my ($this, $fontname) = @_;
    my $scalex = $this->{'_scalex'} || 1;
    my $scaley = $this->{'_scaley'} || 1;
    return ( $this->{$fontname}->{'width'} / $scalex, $this->{$fontname}->{'height'} / $scaley );
}

sub Vpx2bp {
    my ($this, $fontname) = @_;
    my $scalex = $this->{'_scalex'} || 1;
    my $scaley = $this->{'_scaley'} || 1;
    return (int($this->{$fontname}->{'width'} / $scaley), int($this->{$fontname}->{'height'} / $scalex));
}

sub scalex {
    my ($this, $val) = @_;
    $this->{'_scalex'} = $val if(defined $val);
    return $this->{'_scalex'};
}

sub scaley {
    my ($this, $val) = @_;
    $this->{'_scaley'} = $val if(defined $val);
    return $this->{'_scaley'};
}

sub width {
    my ($this, $fontname) = @_;
    return $this->{$fontname}->{'width'} if(defined $this->{$fontname});
}

sub height {
    my ($this, $fontname) = @_;
    return $this->{$fontname}->{'height'} if(defined $this->{$fontname});
}
1;
