#----------------------------------------------------------------------
#
# TODO docs
#
#----------------------------------------------------------------------

package EnsEMBL::Web::BlastView::MetaHyperlink;

use strict;
use warnings;
no warnings "uninitialized";

use Data::Dumper;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::SpeciesDefs;

use EnsEMBL::Web::BlastView::Meta;


use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::BlastView::Meta);
our $SD = EnsEMBL::Web::SpeciesDefs->new();

sub _object_template{ 
  return 
    (
     -type       => '', # Type of hyperlink (internal/external)
     -parent     => '', # Name of parent object
     -href_tmpl  => '', # Template for the hyperlink
     -attributes => [], # List of attributes to substitute into tmpl
     -species    => '', # For ensembl hyperlinks - species script to link to
    );  
}

#----------------------------------------------------------------------
#sub new{
#  my $caller = shift;
#  my $class = ref( $caller ) || $caller
#  my $self  = $class->SUPER::new();
#  return $self;
#}

#----------------------------------------------------------------------
#
sub gen_hyperlink{
  my $self = shift;
  my $href = $self->gen_href(@_);
  my $type = $self->get_type();
  if( $type eq 'geneid' ){$type = 'exturl'};
  my $html_tmpl = '<A href="%s" class="%s" target="%s">%s</A>';
  my $html = sprintf( $html_tmpl, $href, $type, $type, "%s" );
#  warn( $html );
  return $html;
}

#----------------------------------------------------------------------
sub gen_href_tmpl{
  my $self = shift;
  my $type = $self->get_type;
  my $href_tmpl = "%s";

  if( $type eq 'exturl' ){
    my $exturl = EnsEMBL::Web::ExtURL->new( $self->get_species, $SD );
    $href_tmpl = $exturl->get_url( $self->get_href_tmpl ); 
    #			   'ZZZZZZZZZZ' );
    $href_tmpl =~ s/%/%%/g; # Escape '%' for printf's
    #$href_tmpl =~ s/ZZZZZZZZZZ/%s/g;
    $href_tmpl =~ s/###\w+###/%s/g;
    return $href_tmpl;
  }

  my $server;
  my $port;
  my $protocol = 'http';
  if( $type eq 'ensembl' ){
    $server = $SiteDefs::ENSEMBL_SERVERNAME;
    $port   = $SiteDefs::ENSEMBL_PROXY_PORT;
    $protocol = $SiteDefs::ENSEMBL_PROTOCOL;
  }
  else{
    $server = 'www.ensembl.org';
  }

  $href_tmpl = $self->get_href_tmpl();
  if( $port and $port != 80 ){
    $server = "$server:$port";
  }
  if( $href_tmpl =~ /^\// ){ 
    $href_tmpl = "$protocol://${server}${href_tmpl}" 
  }
  else{ 
    my $species = $self->get_species;
    $species =~ s/Multi_species/Multi/;
    $href_tmpl = "$protocol://$server/$species/$href_tmpl";
  };
  return $href_tmpl;
}

#----------------------------------------------------------------------
#
sub gen_href{
  my $self = shift;
  my %results = %{shift @_};

  my $href_tmpl = $self->gen_href_tmpl;
  my $href = sprintf( $href_tmpl, 
		      map{ $results{$_} } $self->get_attributes );
  return $href;
}

1;
