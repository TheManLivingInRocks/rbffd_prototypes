class Get_buffer
{
  int i,ista,iend,ix,iy,il,j,jc,jsta,jend,jx,jy,jx_min,jx_max,jy_min,jy_max;
  double xc,yc,xi,yi,gi,wi,ei,xj,yj,gj;
public:
  void get_buffer(PARTICLE *particle, CLUSTER *cluster, int ic)
  {
    cluster->buffer_length = cluster->sigma_buffer*particle->sigma/2+epsf;
    
    /*
      loop through all clusters
    */
    ista = cluster->ista[ic];
    iend = cluster->iend[ic];
    if (ista <= iend) {
      xc = cluster->xc[ic];
      yc = cluster->yc[ic];
      ix = cluster->ix[ic];
      iy = cluster->iy[ic];
      jx_min = std::max(0,ix-cluster->neighbor_buffer);
      jx_max = std::min(cluster->nx-1,ix+cluster->neighbor_buffer);
      jy_min = std::max(0,iy-cluster->neighbor_buffer);
      jy_max = std::min(cluster->ny-1,iy+cluster->neighbor_buffer);

    /*
      put all particles in the center box into the corresponding cell structure
    */
      i = -1;
      for (j=ista; j<=iend; j++) {
        i++;
        cluster->xib[i] = particle->xl[j];
        cluster->yib[i] = particle->yl[j];
        cluster->gib[i] = particle->gl[j];
        cluster->eib[i] = particle->el[j];
        cluster->wib[i] = particle->wl[j];
        cluster->idx[i] = cluster->ilocal[j];
      }

    /*
      loop through all neighbors
    */
      for (jx=jx_min; jx<=jx_max; jx++) {
        for (jy=jy_min; jy<=jy_max; jy++) {
          if (ix != jx || iy != jy) {
            jc = jx*cluster->ny+jy;
            jsta = cluster->jsta[jc];
            jend = cluster->jend[jc];

    /*
      select from the particles in the neighbor boxes, the ones that belong in the buffer zone
    */
            if (jsta <= jend) {
              for (j=jsta; j<=jend; j++) {
                xi = particle->xl[j];
                yi = particle->yl[j];
                gi = particle->gl[j];
                ei = particle->el[j];
                wi = particle->wl[j];

    /*
      add all particles in the neighbor boxes into the corresponding cell structure
    */
                if (fabs(xi-xc) < cluster->buffer_length && fabs(yi-yc) < cluster->buffer_length) {
                  i++;
                  cluster->xib[i] = xi;
                  cluster->yib[i] = yi;
                  cluster->gib[i] = gi;
                  cluster->eib[i] = ei;
                  cluster->wib[i] = wi;
                  cluster->idx[i] = cluster->ilocal[j];
                }
              }
            }
          }
        }
      }
      cluster->npbufferi = i+1;
    }
    else {
      cluster->npbufferi = 0;
    }
    if (cluster->file == 1) {
      std::ofstream fid;
      fid.open("buffer.dat", std::ios::app);
      fid << cluster->npbufferi << " ";
      for (i=0; i<cluster->npbufferi; i++) fid << cluster->xib[i] << " ";
      for (i=0; i<cluster->npbufferi; i++) fid << cluster->yib[i] << " ";
      fid.close();
    }
  }
};