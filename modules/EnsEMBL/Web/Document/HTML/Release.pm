package EnsEMBL::Web::Document::HTML::Release;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'version' => '??', 'date' => '??? ????', 'site_name' => '??????' );}
sub version   :lvalue { $_[0]{'version'}; }
sub date      :lvalue { $_[0]{'date'}; }
sub site_name :lvalue { $_[0]{'site_name'}; }
sub dbserver  :lvalue { $_[0]{'dbserver'}; }
sub db        :lvalue { $_[0]{'db'}; }

sub render {
  my $self = shift;
  my $sd = $ENSEMBL_WEB_REGISTRY->species_defs;
  $self->printf(
    q(%s release %d - %s - %s
    <a class="modal_link" id="p_link" href="#">Permanent link</a> -
    <a class="modal_link" id="a_link" href="#">View in archive site</a>),
    $sd->ENSEMBL_SITE_NAME, $sd->ENSEMBL_VERSION,
    $sd->ENSEMBL_RELEASE_DATE,
    $sd->SPECIES_COMMON_NAME ? sprintf( '%s <i>%s</i> %s -', $sd->SPECIES_COMMON_NAME, $sd->SPECIES_BIO_NAME, $sd->ASSEMBLY_ID ): '',
    $sd->SPECIES_BIO_NAME,
    $sd->ASSEMBLY_ID
  );
}
=cut

1;

