# $Id$

package EnsEMBL::Web::Document::Renderer::Excel;

use strict;

use Spreadsheet::WriteExcel;

use EnsEMBL::Web::Document::Renderer::Excel::Table;
use EnsEMBL::Web::Document::Renderer::Excel::Cell;

use base qw(EnsEMBL::Web::Document::Renderer);

sub new {
  ### Builder function
  ### Creates a new build function which sets sheets to -1 (i.e. no sheet created)
  ### rows and columns to 0 and creates the workbook
  
  my $class    = shift;
  my $fh       = shift;
  my $workbook = new Spreadsheet::WriteExcel($fh);
  
  my $self = $class->SUPER::new(
    sheet    => -1,
    row      => 0,
    col      => 0,
    workbook => $workbook,
    format   => {},
    colour   => {
      _max_value => 9,
      000000     => $workbook->set_custom_color(8, 0, 0, 0),
      ffffff     => $workbook->set_custom_color(9, 255, 255, 255),
    },
    @_
  );
  
  
  $self->r->content_type('application/x-msexcel');
  $self->r->headers_out->add('Content-Disposition' => 'attachment; filename=ensembl.xls');
  
  return $self;
}

sub sheet     :lvalue { $_[0]->{'sheet'};     }
sub row       :lvalue { $_[0]->{'row'};       }
sub col       :lvalue { $_[0]->{'col'};       }
sub width     :lvalue { $_[0]->{'width'};     }
sub workbook  :lvalue { $_[0]->{'workbook'};  }
sub format    :lvalue { $_[0]->{'format'};    }
sub colour    :lvalue { $_[0]->{'colour'};    }

sub set_width { $_[0]->width = $_[1];         }
sub new_cell  { $_[0]->col++;                 }
sub new_row   { $_[0]->row++; $_[0]->col = 0; }

sub new_sheet {
  my $self = shift;
  my $name = shift;
  
  $self->sheet++;
  $self->row = 0;
  $self->col = 0;
  $self->workbook->add_worksheet($name);
}

sub new_table_renderer {
  my $self = shift;
  return new EnsEMBL::Web::Document::Renderer::Excel::Table($self);
}

sub new_cell_renderer {
  my ($self, $args) = @_;
  
  $args ||= {};
  $args->{'format'}   = $self->format;
  $args->{'colour'}   = $self->colour;
  $args->{'workbook'} = $self->workbook;
  
  return new EnsEMBL::Web::Document::Renderer::Excel::Cell($args);
}

sub printf { shift->print(@_, 'printf'); }

sub print {
  my $self   = shift;
  my $method = $_[-1] eq 'printf' ? pop @_ : 'print';
  
  $self->new_row if $self->col;
  
  my $worksheet = $self->workbook->sheets($self->sheet);
  my $format;
  
  if (@_ && ref($_[-1]) eq 'EnsEMBL::Web::Document::Renderer::Excel::Cell') {
    $format = pop @_;
  } else {
    $format = $self->new_cell_renderer;
  }
  
  my $content = $method eq 'printf' ? sprintf(@_) : join('', @_);
  
  $worksheet->merge_range($self->row, 0, $self->row, $self->width - 1, $content, $format->evaluate);
  $self->new_row;
}

sub write_cell {
  my $self = shift;
  $self->write_sheet($self->row, $self->col, @_);
  $self->new_cell;
}

sub write_sheet {
  ### Arg[1]      : row to print to
  ### Arg[2]      : column (or start column if you pass an array of data)
  ### Arg[3]      : string or array ref of data (array ref, one value per cell)
  ### Arg[4]      : format (optional)
  ### Example     : $output->write_sheet(2, 0, \@my_friends, $bold_format)
  ### Description : Addes worksheet to excel workbook (filehandle)
  ### Returns none

  my $self      = shift;
  my $row       = shift || 0;
  my $col       = shift || 0;
  my $text      = shift;
  my $format    = shift;
  my $worksheet = $self->workbook->sheets($self->sheet);
  
  return unless $worksheet;
  
  $worksheet->write($row, $col, $text, $format->evaluate);
}

sub close { 
  my $self = shift;
  
  return unless $self->workbook;
  
  $self->workbook->close;
  $self->workbook = undef;
}

1;
