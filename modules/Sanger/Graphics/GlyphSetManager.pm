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
