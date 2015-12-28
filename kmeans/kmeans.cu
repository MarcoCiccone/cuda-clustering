#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <iostream>
#include <cuda.h>
#include <cutil.h>
#include <time.h>
#include <device_functions.h>
#include "cutil_inline.h"
#include <shrQATest.h>
#include <math.h>


    // OpenGL Graphics includes
#include <GL/glew.h>
#ifdef _WIN32
#include <GL/wglew.h>
#endif 
#if defined(__APPLE__) || defined(__MACOSX)
#include <GLUT/glut.h>
#else
#include <GL/freeglut.h>
#endif

/*
 
 TODO:
 
 ripulire il codice opengl
 spostare il ricalcolo del centroide nel kernel cuda
 parametrizzare il numero dei kernel e il nome del file di testo.
 ricreare uno storico per ogni centroide.
 
 Spostare nelle funzioni dove � possibile.
 cercare lo zoom da mandelbrot
 
 ATTENZIONE per come � implementata adesso � inutile ricaricare i dati dei centroidi dal device
 
 h_odata
 */


/*
 Data on Device : 
 valpoint d_idata
 __constant__ centroid constData
 [d_centroids is not use anymore] now is used constData
 
 Data on Host : 
 valpoint h_idata
 centroid h_centroids
 
 */


/*
 
 STEPS OF THE ALGORITHM: 
 Step 1: Place randomly initial group centroids into the 2d space.
 Step 2: Assign each object to the group that has the closest centroid.
 Step 3: Recalculate the positions of the centroids.
 Step 4: If the positions of the centroids didn't change go to the next step, else go to Step 2.
 Step 5: End 
 */


    // Constants -----------------------------------------------------------------

#define kWindowWidth	1024
#define kWindowHeight	720
#define namefile "gps/firenze.gps"

#define XLucca 43.8
#define YLucca 10.5

#define XFirenze 43.7
#define YFirenze 11.2

#define offsetLongFirenze -1200.0
#define offsetLatFirenze  -300.0

#define offsetLongLucca -300.0
#define offsetLatLucca  300.0

typedef struct {
    float x;
    float y;
    int index_cluster;
}valpoint;

typedef struct {
    float x;
    float y;
    unsigned long numMembers;
        //centroid * history;
}centroid;


static valpoint* h_idata;
static centroid* h_centroids;
static unsigned long numElements;
static unsigned long numClusters = 68;
static const char* input_file;
static const char* output_file = "output.txt";

    // Function Prototypes -------------------------------------------------------

GLvoid InitGL(GLvoid);
GLvoid DrawGLScene(GLvoid);
GLvoid glCircle3f(GLfloat x, GLfloat y, GLfloat radius); 


    // InitGL -------------------------------------------------------------------

GLvoid InitGL(GLvoid)
{
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);		// This Will Clear The Background Color To Black
        //Setup a 2D projection
    glMatrixMode (GL_PROJECTION);
    glLoadIdentity ();                          // Reset The Projection Matrix
    glOrtho (0, kWindowWidth, kWindowHeight, 0, 0, 1);
    glDisable(GL_DEPTH_TEST);
        // Calculate The Aspect Ratio Of The Window
    glMatrixMode (GL_MODELVIEW);
    glLoadIdentity();
    
    
}


    // DrawGLScene --------------------------------------------------------------

GLvoid DrawGLScene(GLvoid)
{    
	float XX=0,YY=0;
	float offsetLong=0 , offsetLat = 0;   
	if (strstr(input_file,"firenze") != NULL){
		XX = XFirenze;
		YY = YFirenze;
		offsetLong = offsetLongFirenze;
		offsetLat = offsetLatFirenze;
	}
	if (strstr(input_file,"lucca") != NULL){
		XX = XLucca;
		YY = YLucca;
		offsetLong = offsetLongLucca;
		offsetLat = offsetLatLucca;
	}
        //Displacement trick for exact pixelization
    glTranslatef(0.375, 0.375, 0);
        //Draw a scene
    glClear(GL_COLOR_BUFFER_BIT);
        //glColorPointer(3, GL_FLOAT, 0, colorArray);
    
    int i=0,Vertex=0;   
    GLfloat x1 = 0.0 , y1 = 0.0;
    
    
    offsetLong = kWindowWidth * offsetLong / 1440;
    offsetLat = kWindowHeight * offsetLat / 900;
    
    GLfloat colorArray [256 * 256][3]; // color array
    
        // loop over all vertices 
    srand (time(NULL)) ;
    for (int z = 0; z < 256; z++)
    {
        for (int x = 0; x < 256; x++)
        {
                // VERTEX - vertices are numbered left to right, top to bottom
            Vertex = (z * 256) + x;
            
                // COLOUR - set the values in the color array 
                // RGB] = set same colour value to all 3 colours
            colorArray[Vertex][0] = (rand()%255)/255.0;
            colorArray[Vertex][1] = (rand()%255)/255.0;
            colorArray[Vertex][2] = (rand()%255)/255.0;
                //printf("%f    %f    %f  \n",colorArray[Vertex][0],colorArray[Vertex][1],colorArray[Vertex][2]);
            
            
        }
    }
    
    for (i=0; i<numElements; i++) {    
        x1 = (h_idata[i].x-XX);
        y1 = (h_idata[i].y-YY);
        
            //26000 : 1440 = fattoreLong : kWindowWidth --->   fattoreLong = kWindowWidth * 26000 / 1440
        x1 = x1*(kWindowWidth * 26000 / 1440)+offsetLong;
        y1 = y1*(kWindowHeight * 13000 / 900)+offsetLat;
        
        /*if (x1 > kWindowWidth || y1>kWindowHeight){
         printf("Lat: %f --> px: %f \t Long: %f --> px: %f \n",h_idata[i].x,x1,h_idata[i].y,y1);
         
         getchar();
         }*/
        
        glBegin(GL_POINTS);// Start Drawing A Point
        glColor3f(colorArray[h_idata[i].index_cluster][0],colorArray[h_idata[i].index_cluster][1],colorArray[h_idata[i].index_cluster][2]);
        glVertex2f(x1, y1);
        glEnd();   
        
            //printf("Lat: %f --> px: %f \t Long: %f --> px: %f   index cluster : %i    \n",h_idata[i].x,x1,h_idata[i].y,y1,h_idata[i].index_cluster);
        
    }
    
        //disegno i centroidi
    for (i=0;i<numClusters;i++){
        x1 = (h_centroids[i].x-XX);
        y1 = (h_centroids[i].y-YY);
        
        x1 = x1*(kWindowWidth * 26000 / 1440)+offsetLong;
        y1 = y1*(kWindowHeight * 13000 / 900)+offsetLat;
        glColor3f(colorArray[i][0],colorArray[i][1],colorArray[i][2]);
        glCircle3f(x1,y1,5.0);
    }
    
    
        // When we've finished rendering the scene, we display it with
    glutSwapBuffers();
    
}

    // OpenGL keyboard function
void keyboardFunc(unsigned char k, int, int)
{
    switch (k){
        case '\033':
        case 'q':
        case 'Q':
            printf("Shutting down...\n");
            exit(EXIT_SUCCESS);
            break;
            
    }
}

__constant__ centroid constData[4096];
__global__ void KmeansKernel( valpoint* g_idata, centroid* g_centroids, int numClusters,int numElements) {
    
    unsigned long valindex = blockIdx.x * 512 + threadIdx.x ;
    
    if (valindex < numElements){
        int k, myCentroid;
        float minDistance;
        float euclideDistance;
        
        float X_sumCentroid = 0, Y_sumCentroid = 0;
        int countCentroid= 0;
        
        minDistance = 0xFFFFFFFF;
        
        for (k = 0; k<numClusters; k++){//per ogni valore della lista viene calcolata la distanza con il centroide di ogni cluster
                // calcolando le distanze controllo di quale cluster fa parte
            euclideDistance = (float)sqrt((pow(g_idata[valindex].x - g_centroids[k].x,2) + pow(g_idata[valindex].y - g_centroids[k].y,2)));
            if (euclideDistance < minDistance) {
                minDistance = euclideDistance;			
                myCentroid = k;
            }
        }
        
        g_idata[valindex].index_cluster = myCentroid;
            //g_centroids[myCentroid].numMembers++;
        
        __syncthreads();
        
        
            // quando hanno finito tutti i thread magari posso fare qualcosa che puo' essere paralizzata, come ad esempio il ricalcolo del centroide

        if (valindex < numClusters) {
            countCentroid= 0;
            X_sumCentroid=0;
            Y_sumCentroid=0;
                // faccio calcolare per ognuno di dei cluster il nuovo centroide
                //            printf("VALINDEX : %i \n\n",valindex);    
                //getchar();
            for (int i=0;i<numElements;i++){
                    //printf("value %f   %f  Cluster %i  \n",h_odata[i].x,h_odata[i].y,h_odata[i].index_cluster);
                if (g_idata[i].index_cluster == valindex){
                    X_sumCentroid += g_idata[i].x;
                    Y_sumCentroid += g_idata[i].y;
                    countCentroid++;
                }
            }
            if (countCentroid > 0){
                g_centroids[valindex].x = (float)(X_sumCentroid/countCentroid);
                g_centroids[valindex].y = (float)(Y_sumCentroid/countCentroid);
            }
            g_centroids[valindex].numMembers = countCentroid;
            
        }
        
        
            // atomicAdd(c,changes);
        __syncthreads();
        
        
        
    }
}



GLvoid glCircle3f(GLfloat x, GLfloat y, GLfloat radius) 
{ 
    float angle; 
    glLineWidth(1.0f); 
    glBegin(GL_LINE_LOOP); 
    for(int i = 0; i < 100; i++) { 
        angle = i*2*M_PI/100; 
        glVertex2f(x + (cos(angle) * radius), y + (sin(angle) * radius)); 
    } 
    glEnd(); 
}





/*INIZIO MAIN */
int main( int argc, char** argv) 
{
	if (argc != 3){
		printf("params : nameinputfile NumKluster");
		return 1;
	}

	numClusters = atoi(argv[2]);

	if (numClusters<1){
		printf("Il valore di k deve essere un intero maggiore di 1, verrà utilizzzato il default 68" );
		numClusters = 68;
	}
	
	input_file = argv[1];
	
    unsigned int mem_size;
    float gridDimension = 0;
    valpoint *d_idata, *h_odata;
    centroid *d_centroids;
    centroid* h_ocentroids;
    
    float changes =0,change;
    int i=0;
    
    timeval start;
    gettimeofday(&start, NULL);
    
    CUT_DEVICE_INIT(argc, argv);
        //CUT_SAFE_CALL( cutCreateTimer( &timer));
    
    
    
    /***************************************************/
        // initialize the memory reading from text file
    char *line = NULL;
    char linefix[120];
    FILE *inFilePtr;
    inFilePtr = fopen(input_file, "r+");
        
	if (inFilePtr == NULL) {
	   printf("Failed to open file %s",input_file);
	   return -1;
	}    
        //calculate number of points from text file
    while ( fgets ( linefix, sizeof linefix, inFilePtr ) != NULL ) /* read a line */{
        numElements++;
    }
    
        //    numClusters = numElements / 256;
    mem_size = numElements * sizeof(valpoint);
    
        // allocate host memory
    h_idata = (valpoint*) malloc( mem_size);
    h_centroids = (centroid*)malloc (numClusters * sizeof(centroid)); // questi sono quelli inziali e che poi sostituisco via via
    /*h_ocentroids = (centroid*)malloc (numClusters * sizeof(centroid));*/ // questi sono quelli che recupero dal calcolo sul device
    /***************************************************/
    
    
    
    /***************************************************/
    rewind(inFilePtr); // BOF
    for (i=0; i<numElements; i++) {
        
            //read latitude
        fscanf(inFilePtr, "%f", &h_idata[i].x);
            //read longitude
        fscanf(inFilePtr, "%f", &h_idata[i].y);
            //read image HTTP [NOT USED]
        fscanf(inFilePtr, "%s", &line);
            //printf("Lat: %f   Long %f  \n",x,y);
        
        h_idata[i].index_cluster = 999;
    }
    /***************************************************/
    
    
    
    /***************************************************/
    srand (time(NULL)) ;
    int randomIndex;
    for(i = 0; i < numClusters; ++i){
            //random choose the centroids
        randomIndex = rand() % numElements;
        h_centroids[i].x = h_idata[randomIndex].x;
        h_centroids[i].y = h_idata[randomIndex].y;
        h_centroids[i].numMembers = 0;
        
    }
    /***************************************************/
    
    /*for(i = 0; i < numClusters; ++i){
     printf("%f     %f  \n",h_centroids[i].x,h_centroids[i].y);
     }*/
    
        //CUT_SAFE_CALL( cutStartTimer( timer));
    int iteration=1;
    while(1){
        
        
        
            // allocate device memory for data points
        CUDA_SAFE_CALL(cudaMalloc( (void**) &d_idata, mem_size));
            // copy data points to device  [src] d_idata -> [destination] h_idata
        CUDA_SAFE_CALL(cudaMemcpy(d_idata,h_idata, mem_size, cudaMemcpyHostToDevice) );
        
            // allocate device memory for data points
        CUDA_SAFE_CALL(cudaMalloc( (void**) &d_centroids, sizeof(centroid)* numClusters));
        
            // copy centroids to device: [src symbol] h_centroids -> [destination device] constData (or d_centroids)
        CUDA_SAFE_CALL(cudaMemcpy(d_centroids, h_centroids,sizeof(centroid)* numClusters,cudaMemcpyHostToDevice));
        
            // setup execution parameters
        
            //printf("%i \n",numElements);
        
        
        /***************************************************/    
            //numero elenti:  54597 (COME SUDDIVIDERLI???) (faccio eseguire un po' piu di thread? e poi dentro non faccio niente se l'id del thread � maggiore del numero di elementi
        
        gridDimension = (float)numElements / 512; // per adesso la dimensione � fissata a 512 x 1 x 1 poi facciamo altre prove
        
        dim3 grid(ceil(gridDimension), 1); //2048 blocks.
            // numElements can be up to 32 Mega samples
        dim3 threads( 512, 1, 1); // each block having 512 threads. The maximum is 768
        
        /***************************************************/
        
        
            //printf("Main thread: about to dispatch kernel...\n");
        
        KmeansKernel<<< grid, threads >>>(d_idata, d_centroids, numClusters, numElements/*,&changes*/);
        
            // check if kernel execution generated and error
        CUT_CHECK_ERROR("Kernel execution failed");
            //allocate mem for the result on host side
        
        
        h_odata = (valpoint*) malloc( mem_size);
        h_ocentroids = (centroid*)malloc (numClusters * sizeof(centroid));
        
            // copy result from device to host
        CUDA_SAFE_CALL( cudaMemcpy( h_odata,d_idata, mem_size, cudaMemcpyDeviceToHost) );
        CUDA_SAFE_CALL( cudaMemcpy( h_ocentroids,d_centroids, sizeof(centroid)* numClusters, cudaMemcpyDeviceToHost) );
        
        
            //ricalcolo il centro di massa
            //questa parte adesso �  eseguita sul device per aumentare il livello di parallelismo.
        /***************************************************/
        /*changes = 0;
         valindex=0;
         while (valindex < numClusters) {
         countCentroid= 0;
         X_sumCentroid=0;
         Y_sumCentroid=0;
         // faccio calcolare per ognuno di dei cluster il nuovo centroide
         //            printf("VALINDEX : %i \n\n",valindex);    
         //getchar();
         for (int i=0;i<numElements;i++){
         //printf("value %f   %f  Cluster %i  \n",h_odata[i].x,h_odata[i].y,h_odata[i].index_cluster);
         if (h_odata[i].index_cluster == valindex){
         X_sumCentroid += h_odata[i].x;
         Y_sumCentroid += h_odata[i].y;
         countCentroid++;
         }
         }
         if (countCentroid > 0){
         
         //questo poi pu� essere sommato con atomicSUM CUDA
         h_ocentroids[valindex].x = (float)(X_sumCentroid/countCentroid);
         h_ocentroids[valindex].y = (float)(Y_sumCentroid/countCentroid);
         
         changes += (float)sqrt((pow(h_centroids[valindex].x - h_ocentroids[valindex].x,2) + pow(h_centroids[valindex].y - h_ocentroids[valindex].y,2)));
         
         }
         h_ocentroids[valindex].numMembers = countCentroid;
         
         valindex++;
         }
         /***************************************************/
        
        
            
        
         change = 0.0;
         changes = 0.0;
         for(i = 0; i < numClusters; ++i){
             change = (float)sqrt((pow(h_centroids[i].x - h_ocentroids[i].x,2) + pow(h_centroids[i].y - h_ocentroids[i].y,2)));
         
                 //printf("OLD : %f   %f  count %i -   NEW :  %f %f  Count: %i   Change : %f\n",h_centroids[i].x,h_centroids[i].y,h_centroids[i].numMembers,h_ocentroids[i].x,h_ocentroids[i].y,h_ocentroids[i].numMembers,change);
         
             changes+=change;
         }
            //printf("changes : %f \n",changes);
        
            //getchar();
        
        /*int ccc=0;
        for (i=0;i<numElements;i++){
            if (h_idata[i].index_cluster != h_odata[i].index_cluster){
                printf("Cluster 1    %i Cluster2    %i  \n",h_idata[i].index_cluster,h_odata[i].index_cluster);
                ccc++;
            }
            
        }
        printf("%i",ccc);
        getchar();
        */
        
        /*for (i=0;i<numElements;i++){
         printf("value %f   %f  Cluster %i  \n",h_idata[i].x,h_idata[i].y,h_idata[i].index_cluster);
         
         }
         h_idata = h_odata;
         
         getchar();
         for (i=0;i<numElements;i++){
         printf("value %f   %f  Cluster %i  \n",h_idata[i].x,h_idata[i].y,h_idata[i].index_cluster);
         }
         getchar();*/ 
        
        
            //copio dentro d_idata, d_centroids i nuovi d_odata, d_ocentroids 
        h_idata = h_odata;
        h_centroids = h_ocentroids;
        
        CUDA_SAFE_CALL(cudaFree(d_idata));
        CUDA_SAFE_CALL(cudaFree(d_centroids));
        if (changes <0.01)
            break;
        iteration++;
    }
    
    timeval end;
	gettimeofday(&end, NULL);
	double elapsed = end.tv_sec+end.tv_usec/1000000.0 - start.tv_sec-start.tv_usec/1000000.0;
	
	
	printf("Time elapsed : %f \n",elapsed);
    	
    printf("Iterations : %i \n",iteration);
    
    
    
    FILE *fp;
    fp=fopen("output.txt", "w");
    
    for (i=0;i<numElements;i++){
	 fprintf(fp, "value %f   %f  Cluster %i  \n",h_idata[i].x,h_idata[i].y,h_idata[i].index_cluster);
	 
	 }
    
    fclose(fp);
    
    
    printf("Starting GLUT main loop...\n");
    printf("\n");
    printf("Press [q] to exit\n");
    printf("\n");
    
        //inizia la parte che disegna i pixel con opengl
    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGB | GLUT_DEPTH);
    glutInitWindowSize(kWindowWidth, kWindowHeight); 
    glutInitWindowPosition (100, 100);
    glutCreateWindow (argv[0]);
    
    InitGL();
    
    glutDisplayFunc(DrawGLScene); 
    glutKeyboardFunc(keyboardFunc);
    
    glutMainLoop();
    
    
        //CUT_SAFE_CALL( cutStopTimer( timer));
        //    printf( "Time: \%f(ms)\n", cutGetTimerValue( timer));
        //    CUT_SAFE_CALL( cutDeleteTimer( timer));
    
    /*for (i=0;i<numElements;i++){
     printf("value %f   %f  Cluster %i  \n",h_odata[i].x,h_odata[i].y,h_odata[i].index_cluster);
     }*/
        // cleanup memory
    free( h_idata);
    free( h_odata);
    CUDA_SAFE_CALL(cudaFree(d_idata));
    CUT_EXIT(argc, argv);
    
    /*FINE MAIN*/
    return 0;
}











