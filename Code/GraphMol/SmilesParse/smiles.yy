%pure_parser

%{

  // $Id$
  //
  //  Copyright (C) 2001-2010 Randal Henne, Greg Landrum and Rational Discovery LLC
  //
  //   @@ All Rights Reserved  @@
  //

#include <cstring>
#include <iostream>
#include <vector>

#include <GraphMol/RDKitBase.h>
#include <GraphMol/SmilesParse/SmilesParseOps.h>  
#include <RDGeneral/RDLog.h>
#include "smiles.tab.hpp"

extern int yysmiles_lex(YYSTYPE *,void *);

#define YYDEBUG 1
#define YYLEX_PARAM scanner

void
yysmiles_error( std::vector<RDKit::RWMol *> *ms,
		void *scanner,const char * msg )
{

}


using namespace RDKit;

%}

%parse-param {std::vector<RDKit::RWMol *> *molList}
%parse-param {void *scanner}
 
%union {
  int                      moli;
  RDKit::Atom * atom;
  RDKit::Bond * bond;
  int                      ival;
}

%token <atom> AROMATIC_ATOM_TOKEN ATOM_TOKEN ORGANIC_ATOM_TOKEN
%token <ival> NONZERO_DIGIT_TOKEN ZERO_TOKEN
%token GROUP_OPEN_TOKEN GROUP_CLOSE_TOKEN SEPARATOR_TOKEN LOOP_CONNECTOR_TOKEN
%token MINUS_TOKEN PLUS_TOKEN CHIRAL_MARKER_TOKEN CHI_CLASS_TOKEN CHI_CLASS_OH_TOKEN
%token H_TOKEN AT_TOKEN PERCENT_TOKEN
%token <bond> BOND_TOKEN
%type <moli> cmpd mol branch
%type <atom> atomd element chiral_element h_element charge_element simple_atom
%type <ival>  nonzero_number number ring_number digit
%token ATOM_OPEN_TOKEN ATOM_CLOSE_TOKEN
%token EOS_TOKEN

%%

/* --------------------------------------------------------------- */
cmpd: mol
| cmpd SEPARATOR_TOKEN mol {
  RWMol *m1_p = (*molList)[$1],*m2_p=(*molList)[$3];
  SmilesParseOps::AddFragToMol(m1_p,m2_p,Bond::IONIC,Bond::NONE,true);
  delete m2_p;
  int sz = molList->size();
  if ( sz==$3+1) {
    molList->resize( sz-1 );
  }
}
| cmpd error EOS_TOKEN{
  yyclearin;
  yyerrok;
  BOOST_LOG(rdErrorLog) << "SMILES Parse Error" << std::endl;
  for(std::vector<RDKit::RWMol *>::iterator iter=molList->begin();
      iter!=molList->end();++iter){
    SmilesParseOps::CleanupAfterParseError(*iter);
    delete *iter;
  }
  molList->clear();
  molList->resize(0);
  YYABORT;
}
| cmpd EOS_TOKEN {
  YYACCEPT;
}
| error EOS_TOKEN {
  yyclearin;
  yyerrok;
  BOOST_LOG(rdErrorLog) << "SMILES Parse Error" << std::endl;
  for(std::vector<RDKit::RWMol *>::iterator iter=molList->begin();
      iter!=molList->end();++iter){
    SmilesParseOps::CleanupAfterParseError(*iter);
    delete *iter;
  }
  molList->clear();
  molList->resize(0);
  YYABORT;
}
;

/* --------------------------------------------------------------- */
// FIX: mol MINUS DIGIT
mol: atomd {
  int sz     = molList->size();
  molList->resize( sz + 1);
  (*molList)[ sz ] = new RWMol();
  RDKit::RWMol *curMol = (*molList)[ sz ];
  $1->setProp("_SmilesStart",1);
  curMol->addAtom($1);
  delete $1;
  $$ = sz;
}

| mol atomd       {
  RWMol *mp = (*molList)[$$];
  Atom *a1 = mp->getActiveAtom();
  int atomIdx1=a1->getIdx();
  int atomIdx2=mp->addAtom($2);
  mp->addBond(atomIdx1,atomIdx2,
	      SmilesParseOps::GetUnspecifiedBondType(mp,a1,mp->getAtomWithIdx(atomIdx2)));
  delete $2;
}

| mol BOND_TOKEN atomd  {
  RWMol *mp = (*molList)[$$];
  int atomIdx1 = mp->getActiveAtom()->getIdx();
  int atomIdx2 = mp->addAtom($3);
  if( $2->getBondType() == Bond::DATIVER ){
    $2->setBeginAtomIdx(atomIdx1);
    $2->setEndAtomIdx(atomIdx2);
    $2->setBondType(Bond::DATIVE);
  }else if ( $2->getBondType() == Bond::DATIVEL ){
    $2->setBeginAtomIdx(atomIdx2);
    $2->setEndAtomIdx(atomIdx1);
    $2->setBondType(Bond::DATIVE);
  } else {
    $2->setBeginAtomIdx(atomIdx1);
    $2->setEndAtomIdx(atomIdx2);
  }
  mp->addBond($2,true);
  delete $3;
}

| mol MINUS_TOKEN atomd {
  RWMol *mp = (*molList)[$$];
  int atomIdx1 = mp->getActiveAtom()->getIdx();
  int atomIdx2 = mp->addAtom($3);
  mp->addBond(atomIdx1,atomIdx2,Bond::SINGLE);
  delete $3;
}

| mol ring_number {
  RWMol * mp = (*molList)[$$];
  Atom *atom=mp->getActiveAtom();
  mp->setAtomBookmark(atom,$2);

  Bond *newB = mp->createPartialBond(atom->getIdx(),
				     Bond::UNSPECIFIED);
  mp->setBondBookmark(newB,$2);
  newB->setProp("_unspecifiedOrder",1);
  INT_VECT tmp;
  if(atom->hasProp("_RingClosures")){
    atom->getProp("_RingClosures",tmp);
  }
  tmp.push_back(-($2+1));
  atom->setProp("_RingClosures",tmp);
}

| mol BOND_TOKEN ring_number {
  RWMol * mp = (*molList)[$$];
  Atom *atom=mp->getActiveAtom();
  Bond *newB = mp->createPartialBond(atom->getIdx(),
				     $2->getBondType());
  newB->setBondDir($2->getBondDir());
  mp->setAtomBookmark(atom,$3);
  mp->setBondBookmark(newB,$3);
  INT_VECT tmp;
  if(atom->hasProp("_RingClosures")){
    atom->getProp("_RingClosures",tmp);
  }
  tmp.push_back(-($3+1));
  atom->setProp("_RingClosures",tmp);
  delete $2;
}

| mol MINUS_TOKEN ring_number {
  RWMol * mp = (*molList)[$$];
  Atom *atom=mp->getActiveAtom();
  Bond *newB = mp->createPartialBond(atom->getIdx(),
				     Bond::SINGLE);
  mp->setAtomBookmark(atom,$3);
  mp->setBondBookmark(newB,$3);
  INT_VECT tmp;
  if(atom->hasProp("_RingClosures")){
    atom->getProp("_RingClosures",tmp);
  }
  tmp.push_back(-($3+1));
  atom->setProp("_RingClosures",tmp);
}

| mol branch {
  RWMol *m1_p = (*molList)[$$],*m2_p=(*molList)[$2];
  m2_p->getAtomWithIdx(0)->clearProp("_SmilesStart");
  SmilesParseOps::AddFragToMol(m1_p,m2_p,Bond::UNSPECIFIED,Bond::NONE,false);
  delete m2_p;
  int sz = molList->size();
  if ( sz==$2+1) {
    molList->resize( sz-1 );
  }
}
;
/* --------------------------------------------------------------- */
branch:	GROUP_OPEN_TOKEN mol GROUP_CLOSE_TOKEN { $$ = $2; }
| GROUP_OPEN_TOKEN BOND_TOKEN mol GROUP_CLOSE_TOKEN {
  $$ = $3;
  int sz     = molList->size();
  RDKit::RWMol *curMol = (*molList)[ sz-1 ];
  Bond *partialBond = curMol->createPartialBond(0,$2->getBondType());
  partialBond->setBondDir($2->getBondDir());
  curMol->setBondBookmark(partialBond,
			      ci_LEADING_BOND);
  delete $2;
}
| GROUP_OPEN_TOKEN MINUS_TOKEN mol GROUP_CLOSE_TOKEN {
  $$ = $3;
  int sz     = molList->size();
  RDKit::RWMol *curMol = (*molList)[ sz-1 ];

  Bond *partialBond = curMol->createPartialBond(0,Bond::SINGLE);
  curMol->setBondBookmark(partialBond,
			      ci_LEADING_BOND);
}
;

/* --------------------------------------------------------------- */
atomd:	simple_atom
| ATOM_OPEN_TOKEN charge_element ATOM_CLOSE_TOKEN
{
  $$ = $2;
  $2->setNoImplicit(true);
}
;

/* --------------------------------------------------------------- */
charge_element:	h_element
| h_element PLUS_TOKEN { $1->setFormalCharge(1); }
| h_element PLUS_TOKEN PLUS_TOKEN { $1->setFormalCharge(2); }
| h_element PLUS_TOKEN number { $1->setFormalCharge($3); }
| h_element MINUS_TOKEN { $1->setFormalCharge(-1); }
| h_element MINUS_TOKEN MINUS_TOKEN { $1->setFormalCharge(-2); }
| h_element MINUS_TOKEN number { $1->setFormalCharge(-$3); }
		;

/* --------------------------------------------------------------- */
h_element:      H_TOKEN { $$ = new Atom(1); }
                | number H_TOKEN { $$ = new Atom(1); $$->setMass($1); }
                | chiral_element
		| chiral_element H_TOKEN		{ $$ = $1; $1->setNumExplicitHs(1);}
		| chiral_element H_TOKEN number	{ $$ = $1; $1->setNumExplicitHs($3);}
		;

/* --------------------------------------------------------------- */
chiral_element:	 element
| element AT_TOKEN { $1->setChiralTag(Atom::CHI_TETRAHEDRAL_CCW); }
| element AT_TOKEN AT_TOKEN { $1->setChiralTag(Atom::CHI_TETRAHEDRAL_CW); }
;

/* --------------------------------------------------------------- */
element:	simple_atom
		|	number simple_atom { $2->setMass( $1 ); $$ = $2; }
		|	ATOM_TOKEN
		|	number ATOM_TOKEN	   { $2->setMass( $1 ); $$ = $2; }
		;

/* --------------------------------------------------------------- */
simple_atom:      ORGANIC_ATOM_TOKEN
                | AROMATIC_ATOM_TOKEN
                ;

/* --------------------------------------------------------------- */
ring_number:  digit
| PERCENT_TOKEN NONZERO_DIGIT_TOKEN digit { $$ = $2*10+$3; }
;

/* --------------------------------------------------------------- */
number:  ZERO_TOKEN
| nonzero_number 
;

/* --------------------------------------------------------------- */
nonzero_number:  NONZERO_DIGIT_TOKEN
| nonzero_number digit { $$ = $1*10 + $2; }
;

digit: NONZERO_DIGIT_TOKEN
| ZERO_TOKEN
;

/*
  chival:	CHI_CLASS_TOKEN DIGIT_TOKEN
	| AT_TOKEN
        ;
*/


%%


