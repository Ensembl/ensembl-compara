package EnsEMBL::Web::Document::HTML::Ack;

# Generates acknowledgements

use strict;
use base qw(EnsEMBL::Web::Document::HTML);
use EnsEMBL::Web::RegObj;

sub render {
  my $self = shift;
  
### EG want to acknowledge collaborators. 
# If you add ACKNOWLEDGEMENT entry to an ini file then you get
# a box with the ACKNOWLEDGEMENT text at the bottom of LH menu. It will link to /info/acknowledgement.html which 
# you will have to create
# If you add DB_BUILDER entry to an ini file then you get
# a box with the text DB built by XXX at the bottom of LH menu. It will link to the current species' homepage

  if (my $ack_text = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ACKNOWLEDGEMENT) {
      $self->print( q(<div>
		      <ul>) );
      $self->printf('<li style="list-style:none" title="%s"><a href="%s">%s</a></li>',$ack_text,'/info/acknowledgement.html', $ack_text);

      $self->print( q(
		      </ul>
		      </div>) );
  }

  if (my $db_provider = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->DB_BUILDER) {
      my $spath = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->species_path($ENV{ENSEMBL_SPECIES});
      
      $self->print( q(<div>
		      <ul>) );
      $self->printf('<li style="list-style:none"><a href="%s/Info/Index">DB built by %s</a></li>', $spath , $db_provider);

      $self->print( q(
		      </ul>
		      </div>) );
  }

}

1;
