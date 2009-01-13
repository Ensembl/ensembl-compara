package EnsEMBL::Web::Document::Renderer::Excel;

use strict;
use Spreadsheet::WriteExcel;
use EnsEMBL::Web::Document::Renderer::Table::Excel;
use EnsEMBL::Web::Document::Renderer::CellFormat::Excel;

use Class::Std;

{
  my %Sheet_of            :ATTR( :get<sheet> );
  my %Row_of              :ATTR( :get<row> );
  my %Col_of              :ATTR( :get<col> );
  my %Width_of            :ATTR( :get<width> :set<width> );
  my %Workbook_of         :ATTR( :get<workbook> );
  my %Species_defs_of     :ATTR();
  my %Format_hashref_of   :ATTR( :get<format_hashref> );
  my %Colour_hashref_of   :ATTR( :get<colour_hashref> );

  sub BUILD {
### Builder function
### Creates a new build function which sets sheets to -1 (i.e. no sheet created)
### rows and columns to 0 and creates the workbook!
    my( $self, $ident, $arg_ref ) = @_;
    $Sheet_of{    $ident } = -1; 
    $Row_of{      $ident } = 0; 
    $Col_of{      $ident } = 0; 
    $Workbook_of{ $ident } = Spreadsheet::WriteExcel->new( $arg_ref->{'fh'} );
    $Format_hashref_of{ $ident } = {};
    $Colour_hashref_of{ $ident } = {
      '_max_value' => 9,
      '000000'     => $self->get_workbook->set_custom_color(8, 0, 0, 0),
      'ffffff'     => $self->get_workbook->set_custom_color(9,255,255,255),
    };
  }

  sub new_table_renderer {
### Create a new table renderer.
    my $self = shift;
    return EnsEMBL::Web::Document::Renderer::Table::Excel->new( { 'renderer' => $self } );
  }

  sub valid  {
### Returns a true value if their is a workbook attached (so can write to this)
    my $self = shift;
    return $self->get_workbook;
  }

  sub new_cell_format {
    my( $self, $arg_ref ) = @_;
    $arg_ref ||= {};
    $arg_ref->{ 'format_hashref' } = $self->get_format_hashref ;
    $arg_ref->{ 'colour_hashref' } = $self->get_colour_hashref ;
    $arg_ref->{ 'workbook'       } = $self->get_workbook ;
    my $format = EnsEMBL::Web::Document::Renderer::CellFormat::Excel->new($arg_ref);
    return $format;
  }
  
  sub printf {
    my $self = shift;
    $self->new_row if( $self->get_col );
    my $worksheet = $self->get_workbook->sheets($self->{'sheet'});
    my $format;
    if( @_ && ref( $_[-1] ) eq 'EnsEMBL::Web::Document::Renderer::CellFormat::Excel' ) {
      $format = pop @_;
    } else {
      $format = $self->new_cell_format();
    }
    $worksheet->merge_range(
      $self->get_row,0,$self->get_row,$self->get_width-1,sprintf(@_),$format->evaluate
    );
    $self->new_row;
  }
 
  sub print {
    my $self = shift;
    $self->new_row if( $self->get_col );
    my $worksheet = $self->get_workbook->sheets($self->get_sheet);
    my $format;
    if( @_ && ref( $_[-1] ) eq 'EnsEMBL::Web::Document::Renderer::CellFormat::Excel' ) {
      $format = pop @_;
    } else {
      $format = $self->new_cell_format();
    }

    $worksheet->merge_range(
      $self->get_row,0,$self->get_row,$self->get_width-1,join('',@_),$format->evaluate
    );
    $self->new_row
  }
 
  sub close  { 
    my $self = shift;
    return unless $self->get_workbook;
    $self->get_workbook->close;
    $Workbook_of{ ident $self } = undef;
  }

  sub DESTROY {
    my $self = shift;
    $self->close;
  }

  sub write_cell {
    my $self = shift;;
    $self->write_sheet( $self->get_row, $self->get_col, @_ );
    $self->new_cell;
  }

  sub new_cell {
    my $self = shift;
    my $ident = ident $self;
    $Col_of{ $ident } ++;
  }

  sub new_row {
    my $self = shift;
    my $ident = ident $self;
    $Row_of{ $ident } ++;
    $Col_of{ $ident } =0;
  }

  sub new_sheet {
    my $self = shift;
    my $ident = ident $self;
    my $name = shift;
    $Sheet_of{ $ident }++;
    $self->get_workbook->add_worksheet( $name );
    $Row_of{ $ident } =0;
    $Col_of{ $ident } =0;
  }

  sub write_sheet {
  ### Arg[1]      : row to print to
  ### Arg[2]      : column (or start column if you pass an array of data)
  ###  Arg[3]      : string or array ref of data (array ref, one value per cell)
  ### Arg[4]      : format (optional)
  ### Example     : $output->write_sheet(2, 0, \@my_friends, $bold_format)
  ### Description : Addes worksheet to excel workbook (filehandle)
  ### Returns none

    my $self   = shift;
    my $row    = shift || 0;
    my $col    = shift || 0;
    my $text   = shift;
    my $format = shift;
    my $worksheet = $self->get_workbook->sheets($self->get_sheet);
    return unless $worksheet;
  }
}

1;
