package Bio::EnsEMBL::GlyphSetManager;
use strict;
use Exporter;
use SiteDefs;
use vars qw(@ISA);
@ISA = qw(Exporter);

sub new {
    my ($class, $VirtualContig, $Config, $highlights, $strand) = @_;
    my $self = {
	'container'  => $VirtualContig,
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
