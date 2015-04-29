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

#########
# Author: js5@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2002
#
package Sanger::Graphics::GlyphSetManager;
use strict;

sub new {
    my ($class, $Container, $Config, $highlights, $strand) = @_;
    my $self = {
	'container'  => $Container,
	'config'     => $Config,
	'highlights' => $highlights,
	'strand'     => $strand,
	'glyphsets'  => [],
	'label'      => "GlyphSetManager",
    };
    bless $self, $class;

    $self->init() if($self->can('init'));
    return $self;
}

sub glyphsets {
    my ($self) = @_;
    return @{$self->{'glyphsets'}};
}

sub label {
    my ($self, $label) = @_;
    $self->{'label'} = $label if(defined $label);
    return $self->{'label'};
}
1;
