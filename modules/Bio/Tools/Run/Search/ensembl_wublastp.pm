
=head1 NAME

Bio::Tools::Run::Search::ensembl_wublastp - Ensembl BLASTP searches

=head1 SYNOPSIS

  see Bio::Tools::Run::Search::EnsemblBlast
  see Bio::Tools::Run::Search::wublastp

=head1 DESCRIPTION

Multiple inheretance object combining
Bio::Tools::Run::Search::EnsemblBlast and
Bio::Tools::Run::Search::wublastp

=cut

# Let the code begin...
package Bio::Tools::Run::Search::ensembl_wublastp;
use strict;

use vars qw( @ISA );

use Bio::Tools::Run::Search::EnsemblBlast;
use Bio::Tools::Run::Search::wublastp;

@ISA = qw( Bio::Tools::Run::Search::EnsemblBlast 
           Bio::Tools::Run::Search::wublastp );

BEGIN{
}

# Nastyness to get round multiple inheretance problems.
sub program_name{return Bio::Tools::Run::Search::wublastp::program_name(@_)}
sub algorithm   {return Bio::Tools::Run::Search::wublastp::algorithm(@_)}
sub version     {return Bio::Tools::Run::Search::wublastp::version(@_)}
sub parameter_options{
  return Bio::Tools::Run::Search::wublastp::parameter_options(@_)
}

#----------------------------------------------------------------------
1;

