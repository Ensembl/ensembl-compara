package Bio::EnsEMBL::GlyphSet::ntcontigs;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "NT Contigs"; }

sub features {
    my ($self) = @_;
    my $container_length = $self->{'container'}->length();
    return $self->{'container'}->get_all_MiscFeatures( 'ntctgs' );
}

sub href {
    my ($self, $f ) = @_;
    return qq(/@{[$self->{container}{_config_file_name_}]}/$ENV{'ENSEMBL_SCRIPT'}?miscfeature=@{[$f->get_attribute('name')]});
}

sub colour {
    my ($self, $f ) = @_;
    $self->{'_colour_flag'} = $self->{'_colour_flag'}==1 ? 2 : 1;
    return 
      $self->{'colours'}{"col$self->{'_colour_flag'}"},
      $self->{'colours'}{"lab$self->{'_colour_flag'}"},
      'border';
}

sub image_label {
    my ($self, $f ) = @_;
    return (qq(@{[$f->get_attribute('name')]}),'overlaid');
}

sub zmenu {
  my ($self, $f ) = @_;
  my $offset = $self->{'container'}->start - 1;
    my $zmenu = { 
        qq(caption)                                => qq(NT Contig: @{[$f->get_attribute('name')]}),
        qq(01:bp: @{[$f->start+$offset]}-@{[$f->end+$offset]})     => '',
        qq(02:length: @{[$f->length]} bps)         => '',
        qq(03:Centre on NT ctg)                    => $self->href($f),
    };
    return $zmenu;
}

1;
