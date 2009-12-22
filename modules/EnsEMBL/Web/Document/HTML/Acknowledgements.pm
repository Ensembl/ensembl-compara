package EnsEMBL::Web::Document::HTML::Acknowledgements;

### Generates acknowledgements
### If you add ACKNOWLEDGEMENT entry to an ini file then you get
### a box with the ACKNOWLEDGEMENT text at the bottom of LH menu. It will link to /info/acknowledgement.html which 
### you will have to create
### If you add DB_BUILDER entry to an ini file then you get
### a box with the text DB built by XXX at the bottom of LH menu. It will link to the current species' homepage

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  
  my $species_defs = $self->species_defs;
  my $species_path = $species_defs->species_path;
  my $ack_text     = $species_defs->ACKNOWLEDGEMENT;
  my $db_provider  = $species_defs->DB_BUILDER;
  
  if ($ack_text) {
    $self->print(qq{
      <div>
        <ul>
          <li style="list-style:none"><a href="/info/acknowledgement.html">$ack_text</a></li>
        </ul>
      </div>
    });
  }

  if ($db_provider) {
    $self->print(qq{
      <div>
        <ul>
          <li style="list-style:none"><a href="$species_path/Info/Index">DB built by $db_provider</a></li>
        </ul>
      </div>
    });
  }
}

1;
