package EnsEMBL::Web::Factory::LRG;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Factory);

use CGI qw(escapeHTML);

sub _help {
  my( $self, $string ) = @_;

  my %sample = %{$self->hub->species_defs->SAMPLE_DATA ||{}};

  my $help_text = $string ? sprintf( '
  <p>
    %s
  </p>', CGI::escapeHTML( $string ) ) : '';
  my $url = $self->_url({ '__clear' => 1, 'action' => 'Summary', 'lrg' => $sample{'LRG_PARAM'} });


  $help_text .= sprintf( '
  <p>
    This view requires a LRG identifier in the URL. For example:
  </p>
  <blockquote class="space-below"><a href="%s">%s</a></blockquote>',
    CGI::escapeHTML( $url ),
    CGI::escapeHTML( $self->hub->species_defs->ENSEMBL_BASE_URL. $url )
  );

  return $help_text;
}

sub createObjects { 
  my $self = shift;
  my $id;
  warn "CREATING LRG OBJECTS";

  my $db        = $self->hub->param('db')  || 'core'; 

  # Get the 'central' database (core, est, vega)
  my $db_adaptor  = $self->database($db);
  unless ($db_adaptor){
    $self->problem( 'Fatal', 
		    'Database Error', 
		    $self->_help("Could not connect to the $db database.") ); 
    return ;
  }
	
  my $adaptor = $db_adaptor->get_SliceAdaptor;
  if ($id = $self->hub->param('lrg')) { 

    ## First get the slice
    my $slice;
    eval { $slice = $adaptor->fetch_by_region('LRG', $id) };
    $self->DataObjects( $self->new_object( 'LRG', $slice, $self->__data ));
    
    ## Add the gene(s) - should only be one
    my $genes = $slice->get_all_Genes(); 
    if ($genes->[0]) {
      $self->DataObjects( $self->new_object( 'Gene', $genes->[0], $self->__data));
    } 
    
    ## Add any associated transcripts
    my $transcripts = $slice->get_all_Transcripts(undef, 'LRG_import'); 
    if (@$transcripts) {
      $self->DataObjects( $self->new_object( 'Transcript', $transcripts, $self->__data));
    } 
    
  } 
  else {
    return;
  }
}



#----------------------------------------------------------------------

1;

