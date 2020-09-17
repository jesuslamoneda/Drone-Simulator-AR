//
//  ViewController.swift
//  DroneSimulatorAR
//
//  Created by Jesús Lamoneda on 28/07/2020.
//  Copyright © 2020 UPSA. All rights reserved.
//

import UIKit
import ARKit
import CoreMotion
//import AVFoundation //para reproducir sonidos

class ViewController: UIViewController, ARSCNViewDelegate {
    
    // MARK: - Propiedades
    let motionManager = CMMotionManager() //Nos informa del movimiento detectado por los sensores integrados del dispositivo
    let limiteInclinacion: CGFloat = 0.6
    var inclinacionActualHorizontal: CGFloat = 0
    var inclinacionActualVertical: CGFloat = 0
    var cambioInclinacion:Float = 0.35 //inclinación (1.0 max incremento de gravedad en aceleracion)
    
    var pulsandoPantalla = false
    var movidoHaciaAlante = false
    var movidoHaciaAtras = false
    var movidoHaciaIzquierda = false
    var movidoHaciaDerecha = false
    
    //var player = AVAudioPlayer()
    
    //Nodos
    var DronNode:SCNNode!
    var helice1Node:SCNNode!
    var helice2Node:SCNNode!
    var helice3Node:SCNNode!
    var helice4Node:SCNNode!
    
    //Mostrar Avisos
    var mensajeAviso:String = "" {
        
        didSet { //cuando se asigne un mensaje de aviso, se ejecutará este bloque
            let alerta = UIAlertController(title: "Acción no permitida",
                                           message: mensajeAviso,
                                           preferredStyle: UIAlertController.Style.alert)
            let accion = UIAlertAction(title: "Cerrar",
                                       style: UIAlertAction.Style.default) { _ in
                                        alerta.dismiss(animated: true, completion: nil) };
            alerta.addAction(accion)
            self.present(alerta, animated: true, completion: nil)
        }
    }
    
    //MARK: Estados del Vuelo
    enum EstadosDelVuelo:String {
        
        //case iniciando //iniciando la aplicacion
        case detectarPistaDespegue //se está buscando pista de despegue
        case swipeUpToFly //deslizar hacia arriba para despegar
        case flying //dron volando
        case regresandoInicio //se está regresando a la pista de despegue
    }
    
    var estado:EstadosDelVuelo! {
            
        didSet { //cuando haya cambiado de valor
            
                /*Ya no hacemos uso de ello, directamente cuando se inicie la aplicación se buscará la pista de despegue
            if (estado == EstadosDelVuelo.iniciando) {
                print("Iniciando la sesión")
                self.label_mostrar_info.text = "Iniciando la sesión"
                self.label_mostrar_info.backgroundColor = UIColor.yellow

            } else */
            if (estado == EstadosDelVuelo.detectarPistaDespegue) {
                print("No se detecta plataforma de despegue")
                self.label_mostrar_info.text = "No se detecta plataforma de despegue"
                self.label_mostrar_info.backgroundColor = UIColor.red

            } else if (estado == EstadosDelVuelo.swipeUpToFly) {
                print("Deslizar hacia arriba para despegar el dron")
                self.label_mostrar_info.text = "Deslizar hacia arriba para despegar el dron"
                self.label_mostrar_info.backgroundColor = UIColor.yellow

            } else if (estado == EstadosDelVuelo.flying) {
                print("¡Despegue con éxito!")
                self.label_mostrar_info.text = "¡Despegue con éxito!"
                self.label_mostrar_info.backgroundColor = UIColor.green

            } else if (estado == EstadosDelVuelo.regresandoInicio) {
                print("Regresando a la pista de despegue")
                self.label_mostrar_info.text = "Regresando a la pista de despegue"
                self.label_mostrar_info.backgroundColor = UIColor.orange
            }
        }
    }
    
    // MARK: - Objetos
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var label_mostrar_info: UILabel!
    
    // MARK: - Manejo de Vista
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.iniciarEscena()
    }
    
    override func viewWillDisappear(_ animated: Bool) { //cuando va a desaparecer la vista
        super.viewWillDisappear(animated)

        //Pausa la vista de la sesión
        sceneView.session.pause()
    }
    
    override func viewDidAppear(_ animated: Bool) { //una vez que está cargada la vista mostramos el aviso
        self.mostrarAviso()
    }
    
    func iniciarEscena(){
        
        guard let PistaDespegue = ARReferenceImage.referenceImages(inGroupNamed: "ImagenADetectar", bundle: Bundle.main) else {
            //No hay imagen disponible
            mensajeAviso = "No hay imagen disponible"
            print(mensajeAviso)
            return
        }
        
        let configuration = ARWorldTrackingConfiguration() //definimos el tipo de tracking, entre otras nos permitirá detectar imágenes (incluye la funcionalidad de ARImageTrackingConfiguration())
        
        configuration.detectionImages = PistaDespegue
        configuration.maximumNumberOfTrackedImages = 1 //solo vamos a detectar una imagen
        
        sceneView.delegate = self
        
        //sceneView.showsStatistics = true
        sceneView.debugOptions = [
          //ARSCNDebugOptions.showFeaturePoints,
          //ARSCNDebugOptions.showWorldOrigin,
          //SCNDebugOptions.showPhysicsShapes,
          //SCNDebugOptions.showBoundingBoxes
        ]
        
        sceneView.session.run(configuration)
        estado = EstadosDelVuelo.detectarPistaDespegue
    }
    
    // MARK: - Administración de SceneKit
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? { //pide al delegado que proporcione un nodo SceneKit correspondiente al ancla de la pista de despegue agregado
        
        guard estado == EstadosDelVuelo.detectarPistaDespegue else {
            return nil
        }
        
        let node = SCNNode() //va a ser donde vamos a agregar el drone
        //tenemos que crear un nodo que contenga el drone que se agregará a la vista donde se ha detectado la imagen

        DispatchQueue.main.async { //como este bloque es pesado, permitimos que pueda continuar de forma asincrona y así no bloquearse
            
            if let imageAnchor = anchor as? ARImageAnchor { //la imagen que hemos detectado
                
                print("Nombre de imagen detectada: \(imageAnchor.referenceImage.name!)")
                
                let plano = SCNPlane(width: imageAnchor.referenceImage.physicalSize.width, height: imageAnchor.referenceImage.physicalSize.height) //creamos un plano con las mismas dimensiones que nuestra imagen, y sobre la que situaremos el dron
                
                plano.firstMaterial?.diffuse.contents = UIColor(white: 1.0, alpha: 0.0) //plano transparente
                
                let planeNode = SCNNode(geometry: plano)
                
                //planeNode.opacity = 0.25
                //planeNode.eulerAngles.x = -.pi / 2 //de la documentación, rotación en ángulos de euler para que aparezca plano derecho
                
                let droneScene = SCNScene(named: "art.scnassets/Drone.scn")!
                
                self.DronNode = droneScene.rootNode.childNodes.first! //saca el primer nodo de los nodos raices de la escena, en nuestro caso es el único nodo (que corresponde al dron) y contiene el cuerpo del dron y las helices
                
                self.helice1Node = self.DronNode?.childNode(withName: "Helice_1", recursively: false) //false porque no tenemos ningun nodo dentro, así que no tiene que añadir recursivamente
                self.helice2Node = self.DronNode?.childNode(withName: "Helice_2", recursively: false)
                self.helice3Node = self.DronNode?.childNode(withName: "Helice_3", recursively: false)
                self.helice4Node = self.DronNode?.childNode(withName: "Helice_4", recursively: false)
                
                //droneNode.position = SCNVector3Zero //porque queremos que el dron esté en la posicion 0 del ancla agregada (posicion de la pista), altura 0 y en el medio (0,0,0).
                //Ciertamente esto sería innecesario puesto que un nodo se agrega a otro por defecto en la posición 0
                
                self.DronNode.position = SCNVector3(0, 3, 0) //y=3 para que no aparezca apoyado sobre la pista de despegue, sino que tenga una cierta altura
                
                planeNode.addChildNode(self.DronNode)
                
                node.addChildNode(planeNode)
                
                self.estado = EstadosDelVuelo.swipeUpToFly //listo para hacer swipe up, una vez mostrado el dron en escena
                
                //node.position = SCNVector3(imageAnchor.transform.columns.3.x, imageAnchor.transform.columns.3.y, imageAnchor.transform.columns.3.z)
                
                //sceneView.scene.rootNode.addChildNode(node)
            }
        }
        
        
        return node
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval){
        //hilo permanente que se está ejecutando
        
         DispatchQueue.main.async { //async para que no nos quede este hilo bloqueado sólo para este método, sino que pueda hacer más cosas
            self.actualizarPosicionDrone()
        }
    }
    
    // MARK: - Controles
    @IBAction func swipeUpGesture(_ sender: Any) { //swipe up = deslizamiento hacia arriba en la pantalla
        
        print("Se ha hecho swipe up")
        
        guard estado == EstadosDelVuelo.swipeUpToFly else {
            mensajeAviso = "No se esperaba iniciar el vuelo"
            print(mensajeAviso)
            return
        }
        
        pulsandoPantalla = false //cuando se hace swipe up se toca la pantalla, y no queremos que lo detecte como tal
        self.comenzarVuelo()
        
    }
    
    @IBAction func button_elevar(_ sender: Any) {
        
        let subida:Float = 2.0
        
        guard estado == EstadosDelVuelo.flying else { //sólo se pueden pulsar los botones una vez que el despegue ha sido exitoso (estado de flying)
            mensajeAviso = "Hasta que no despegue el dron, no se pueden pulsar los botones de control"
            print(mensajeAviso)
            return //si estamos en otro estado, no haremos nada
        }
        
        /*
        print("Posicion x: \(DronNode.position.x) y: \(DronNode.position.y) z: \(DronNode.position.z)")
        print("Angulos euler x: \(DronNode.eulerAngles.x) y: \(DronNode.eulerAngles.y) z: \(DronNode.eulerAngles.z)")
        */
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        DronNode.position = SCNVector3(DronNode.position.x, DronNode.position.y + subida, DronNode.position.z) //mueve el dron 2.0 en y con respecto a la posición que ya tenía
        SCNTransaction.commit()
    }
    
    @IBAction func button_bajar(_ sender: Any) {
        
        let bajada:Float = 2.0
        
        guard estado == EstadosDelVuelo.flying else {
            mensajeAviso = "Hasta que no despegue el dron, no se pueden pulsar los botones de control"
            print(mensajeAviso)
            return
        }
        
        if (DronNode.position.y < bajada){
            mensajeAviso = "Altura negativa con respecto a la pista de despegue no permitida"
            print(mensajeAviso)
            return
        }
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        DronNode.position = SCNVector3(DronNode.position.x, DronNode.position.y - bajada, DronNode.position.z)
        SCNTransaction.commit()
    }
    
    @IBAction func button_rotar_izquierda(_ sender: Any) {
        
        guard estado == EstadosDelVuelo.flying else {
            mensajeAviso = "Hasta que no despegue el dron, no se pueden pulsar los botones de control"
            print(mensajeAviso)
            return
        }
        
        let rotate = SCNAction.rotateBy(x: 0, y: -(CGFloat.pi/8), z: 0, duration: 0.2) //2Pi es una vuelta completa, así rota 1/16 vueltas
        
        DronNode.runAction(rotate)
    }
    
    @IBAction func button_rotar_derecha(_ sender: Any) {
        
        guard estado == EstadosDelVuelo.flying else {
            mensajeAviso = "Hasta que no despegue el dron, no se pueden pulsar los botones de control"
            print(mensajeAviso)
            return
        }
        
        let rotate = SCNAction.rotateBy(x: 0, y: (CGFloat.pi/8), z: 0, duration: 0.2)
        DronNode.runAction(rotate)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
           
        /* //no nos vale esta alerta ya que tambien detecta el swipe up
        guard estado == EstadosDelVuelo.flying else {
            mensajeAviso = "Hasta que no despegue el dron no podrá hacer uso de estos controles de movimiento a través de la inclinación del dispositivo"
            print(mensajeAviso)
            return
        }*/
        
        pulsandoPantalla = true
        
    }
       
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        pulsandoPantalla = false
    }
    
    @IBAction func regresar_a_plataforma(_ sender: Any) {
        
        guard estado == EstadosDelVuelo.flying else {
            mensajeAviso = "Para regresar a la pista se necesita que haya despegado antes el dron"
            print(mensajeAviso)
            return
        }
        
        let x_distancia = DronNode.position.x
        let z_distancia = DronNode.position.z
        
        if (x_distancia==0 && z_distancia==0){ //si no se ha movido del punto inicial, no haremos nada
            mensajeAviso = "No se puede regresar a la pista porque ya está en la posición inicial"
            print(mensajeAviso)
            return
        }
        
        let alerta = UIAlertController(title: "Regresar a Inicio", message: "¿Desea regresar a la plataforma de despegue?", preferredStyle: UIAlertController.Style.alert)

        alerta.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in
              print("Se ha aceptado regresar a casa")
              self.pararAcelerometro() //detenemos el acelerómetro ya que no se va a hacer uso de él hasta que volvamos a despegar y consume mucha energía y recursos
              self.volver_a_inicio(x_distancia, z_distancia)
        }))

        alerta.addAction(UIAlertAction(title: "Cancelar", style: .cancel, handler: { (action: UIAlertAction!) in
            print("Se ha cancelado regreso al inicio")
            return
        }))

        present(alerta, animated: true, completion: nil)
    }
    
    // MARK: - Funciones de Ayuda
    func volver_a_inicio (_ x_distancia: Float, _ z_distancia: Float){
        estado = EstadosDelVuelo.regresandoInicio
               
        var anguloAInicio : Float
               
       anguloAInicio = abs(atan(z_distancia/x_distancia)) //calculamos el arcotangente para saber el angulo que hay entre los ejes que nos marcan la distancia x y z
        
       //var anguloAInicio = (Float.pi/2) - atan(z_distancia/x_distancia) //ángulo al que deberá girarse para ir en linea recta a la pista de despegue
        
       var giroEuler = (Float(DronNode.eulerAngles.y)).truncatingRemainder(dividingBy: 2*Float.pi)
       var aplicarSobreEuler : Float = 0
        
        if (giroEuler<0) { //si el ángulo es negativo, será entre -2Pi...0 no inclusives
            
            giroEuler+=(2*Float.pi)
        }
        
        //VERSION 2 sobre calcular aplicarSobreEuler (distancia hasta completar la vuelta y retroceso correspondiente)
        //hace el giro más corto
        
        //VERSION 1 se completaba la vuelta y se evaluaba para que no diera vuelta extra (dos condiciones)
        
       if (x_distancia<0 && z_distancia<0) {
            //Cuadrante 2 según nuestra vista de frente con el dron
        
            //Version 2
            aplicarSobreEuler = (2*Float.pi - giroEuler) - Float.pi - (Float.pi/2 - anguloAInicio)
        
            /*//Version 1
           if ((anguloAInicio + (Float.pi/2)) > giroEuler){ //se encuentra dentro del cuadrante del giro deseado
               aplicarSobreEuler = (anguloAInicio + (Float.pi/2)) - giroEuler
           }
           else {
               aplicarSobreEuler = (2*Float.pi - giroEuler) + anguloAInicio + (Float.pi/2)
           }
            */
       }
       else if (x_distancia>0 && z_distancia<0) {
           //Cuadrante 1
        
            aplicarSobreEuler = (2*Float.pi - giroEuler) - (Float.pi/2) - anguloAInicio
        
            /*
           if ((((Float.pi/2) - anguloAInicio) + (Float.pi)) > giroEuler){
               aplicarSobreEuler = (Float.pi - giroEuler) + ((Float.pi/2)-anguloAInicio)
           }
           else {
               aplicarSobreEuler = (2*Float.pi - giroEuler) + ((Float.pi/2) - anguloAInicio) + (Float.pi)
           }
            */
       }
       else if (x_distancia<0 && z_distancia>0){
           //Tercer cuadrante
        
            aplicarSobreEuler = (2*Float.pi - giroEuler) - (3*Float.pi/2) - anguloAInicio
            /*
           if (((Float.pi/2) - anguloAInicio) > giroEuler) {
               aplicarSobreEuler = ((Float.pi/2) - anguloAInicio) - giroEuler
           }
           else {
               aplicarSobreEuler = (2*Float.pi - giroEuler) + ((Float.pi/2) - anguloAInicio)
           }
            */
       }
       else {
           //cuarto cuadrante
            //no podemos aplicar la misma técnica que al resto de cuadrantes ya que el angulo de giro linda con el final de una vuelta
        
            aplicarSobreEuler = (-giroEuler-((Float.pi/2)-anguloAInicio)).truncatingRemainder(dividingBy: 2*Float.pi)
        
       }
        
       //print(anguloAInicio)
       //print(giroEuler)
       //print(aplicarSobreEuler)
        
       let tiempoRotacionEjeRegresar : CFTimeInterval = 1.0
        
       let rotate = SCNAction.rotateBy(x: 0, y: CGFloat(aplicarSobreEuler), z: 0, duration: tiempoRotacionEjeRegresar)
        
       DronNode.runAction(rotate)
        
        //se ejecutará cuando se haya rotado el dron (despues de pasar su duracion)
       DispatchQueue.main.asyncAfter(deadline: .now() + tiempoRotacionEjeRegresar){
        
           self.DronNode.runAction(SCNAction.rotateBy(x: 0.3, y: 0, z: 0, duration: 0.5)) //inclinacion hacia alante
        
           let velocidadCrucero = 12
           let distanciaArecorrerRecta = abs(x_distancia / cos(anguloAInicio)) //distancia que tiene que recorrer el dron en línea recta en dos ejes para volver
        
           let alturaInicio = 3
           let cambioAltura = abs(Float(self.DronNode.position.y) - Float(alturaInicio))
        
           //hipotenusa de la altura con la distancia el linea recta al dron
           let distanciaArecorrer = sqrt(pow(cambioAltura, 2) + pow(distanciaArecorrerRecta, 2))
        
           let tiempoVuelta = distanciaArecorrer / Float(velocidadCrucero) //tiempo que tardará en volver para la velocidad de crucero, no fijo una duracion de tiempo de vuelta constante para todos los casos ya que por ejemplo cuando esté muy lejos volvería mucho más rápido que si está al lado de la pista de despegue
        
           print("Distancia a recorrer: \(distanciaArecorrer)")
           print("Tiempo que tarda: \(tiempoVuelta)")
        
           SCNTransaction.begin()
           SCNTransaction.animationDuration = CFTimeInterval(tiempoVuelta)
           self.DronNode.position = SCNVector3(0, alturaInicio, 0) //se dirige a la plataforma de inicio a la altura de inicio
           SCNTransaction.commit()
        
           /*
           SCNTransaction.begin()
           SCNTransaction.animationDuration = 2
           self.DronNode.position = SCNVector3(0, 3, 0) //se pone a la altura que tenía antes de despegar
           SCNTransaction.commit()
           */
        
           //INICIO
            //mostraremos el dron tal como se mostraba antes del swipe up
           let tiempoEspera = CFTimeInterval(tiempoVuelta) //en segundos
           self.DronNode.runAction(SCNAction.rotateBy(x: -0.3, y: 0, z: 0, duration: tiempoEspera))
        
           DispatchQueue.main.asyncAfter(deadline: .now() + tiempoEspera) {
            //Dispatch y no un sleep para que no se congele el hilo. Uso esto para que no ocurran animaciones a la vez que regresa el drone, sino una vez después de haber regresado (que es después de haber concluido el tiempo de vuelta)
            
               //mirando hacia adelante
               //let derechoRotacion = SCNAction.rotateTo(x: 0, y: CGFloat.pi, z: 0, duration: 1, usesShortestUnitArc: true)
               //self.DronNode.runAction(derechoRotacion)
            
            
               //gira en loop esperando a despegar (inicio normal)
               let rotacion = SCNAction.rotateBy(x: 0, y: -0.25, z: 0, duration: 0.5)
               let moveSequence = SCNAction.sequence([rotacion])
               let moveLoop = SCNAction.repeatForever(moveSequence)
               self.DronNode.runAction(moveLoop)
            
               //rota las hélices más lento ya que aún no ha despegado
               self.helice1Node.removeAllActions()
               self.helice2Node.removeAllActions()
               self.helice3Node.removeAllActions()
               self.helice4Node.removeAllActions()
            
               let rotacionHelices = SCNAction.rotateBy(x: 0, y: -10, z: 0, duration: 0.5)
               let moveSequenceHelice = SCNAction.sequence([rotacionHelices])
               let moveLoopHelice = SCNAction.repeatForever(moveSequenceHelice)
            
               self.helice1Node.runAction(moveLoopHelice)
               self.helice2Node.runAction(moveLoopHelice)
               self.helice3Node.runAction(moveLoopHelice)
               self.helice4Node.runAction(moveLoopHelice)
            
               self.estado = EstadosDelVuelo.swipeUpToFly
           }

       }

    }
    
    func comenzarVuelo(){
        self.rotarDespegue()
        self.elevarDespegue()
        estado = EstadosDelVuelo.flying
        
        DispatchQueue.main.async {
            self.iniciarAcelerometro()
        }
        
    }
    
    func rotarDespegue() { //acelera las hélices para despegar
        helice1Node.removeAllActions()
        helice2Node.removeAllActions()
        helice3Node.removeAllActions()
        helice4Node.removeAllActions()
        let rotate = SCNAction.rotateBy(x: 0, y: -15, z: 0, duration: 0.5)
        let moveSequence = SCNAction.sequence([rotate])
        let moveLoop = SCNAction.repeatForever(moveSequence)
        helice1Node.runAction(moveLoop)
        helice2Node.runAction(moveLoop)
        helice3Node.runAction(moveLoop)
        helice4Node.runAction(moveLoop)
    }
    
    func elevarDespegue(){ //pone el dron derecho (le quita la rotacion y lo orienta de frente), y lo eleva
        DronNode.removeAllActions()
        
        //vamos a rotar el dron para que quede derecho
        let rotate = SCNAction.rotateTo(x: 0, y: CGFloat.pi, z: 0, duration: 1, usesShortestUnitArc: true) //usesShortestUnitArc para que haga la rotación más directa posible desde la orientación actual del nodo a la nueva orientación, si no lo indico hace un giro brusco y se voltea, un movimiento no natural en el vuelo de un dron
        DronNode.runAction(rotate)
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 3
        DronNode.position = SCNVector3(DronNode.position.x, DronNode.position.y + 5, DronNode.position.z)
        SCNTransaction.commit()
    }
    
    func iniciarAcelerometro(){
        guard motionManager.isAccelerometerAvailable else { //si está disponible el sensor de acelerómetro
            return
        }
           
       motionManager.accelerometerUpdateInterval = 1/60.0 //el acelerómetro se actualizará cada fotograma (60fps = 60hz es la frecuencia de actualización de la imagen en la realidad aumentada)
           
       motionManager.startAccelerometerUpdates(to: OperationQueue.main) { (accelerometerData, error) in
           //cada vez que se vea modificada la aceleración llamaremos a
           self.actualizarInclinacion(aceleracion: accelerometerData!.acceleration)
       }
    }
   
   func pararAcelerometro(){
       motionManager.stopAccelerometerUpdates()
   }
       
   func actualizarInclinacion(aceleracion: CMAcceleration){
       
        inclinacionActualHorizontal = (CGFloat) (aceleracion.y) //inclinacion de derecha a izda
        inclinacionActualVertical = (CGFloat) (aceleracion.z) //inclinacion de alante a atrás
    
        //print("Inclinacion vertical original: \(inclinacionActualVertical)")
        //print("Inclinacion horizontal original: \(inclinacionActualHorizontal)")
    
        inclinacionActualVertical += CGFloat(cambioInclinacion)
        inclinacionActualVertical *= -1 //yo tomo los signos de movimiento como positivo hacia adelante, en la inclinación vertical nos viene al revés
        inclinacionActualVertical = inclinacionActualVertical*4
    
        //para descartar inclinaciones mínimas (se considerará a partir de minimoConsiderar)
        let minimoConsiderar : CGFloat = 0.13
    
        if (inclinacionActualHorizontal > 0 && inclinacionActualHorizontal < minimoConsiderar){
            inclinacionActualHorizontal = 0
        }
        else if (inclinacionActualHorizontal < 0 && inclinacionActualHorizontal > -minimoConsiderar) {
            inclinacionActualHorizontal = 0
        }
        else if (inclinacionActualHorizontal >= minimoConsiderar){
            inclinacionActualHorizontal -= minimoConsiderar
        }
        else if (inclinacionActualHorizontal < -minimoConsiderar) {
            inclinacionActualHorizontal += minimoConsiderar
        }
    
        inclinacionActualHorizontal *= 2
    
        /*
        //Para establecer límite de inclinación
        if (inclinacionActualHorizontal < -limiteInclinacion) {
        //si el inclinacion es mayor a nuestro límite por la derecha
            inclinacionActualHorizontal = -limiteInclinacion //negativo porque es inclinacion a la derecha
        }
        else if (inclinacionActualHorizontal > limiteInclinacion) {
        //si el inclinacion es mayor a nuestro límite por la izquierda
            inclinacionActualHorizontal = limiteInclinacion
        }
        */
    
    }
    
    func actualizarPosicionDrone(){
        guard estado == EstadosDelVuelo.flying else {
            return
        }
        
        var anguloEuler = (Float(DronNode.eulerAngles.y)).truncatingRemainder(dividingBy: 2*Float.pi)
         
         if (anguloEuler<0){ //si el giro era negativo, hago la conversion a positivo
             anguloEuler = 2*Float.pi + anguloEuler
         }
         
         //tengo la informacion de la rotacion del dron en sentido contrario a los cuadrantes, por lo que lo invierto
         anguloEuler = 2*Float.pi - anguloEuler
         
         //La posición 0 del dron corresponde al segundo cuadrante, así que le sumo un cuadrante (PI/2) para pasarlo a la posicion inicial
        
         anguloEuler = anguloEuler + (Float.pi/2)
        
         //print(anguloEuler)
         
         let x_posicion_vertical = cos(anguloEuler) //para calcular el recorrido en el eje de las x, hacemos el coseno del angulo, pura teoria de trigonometria
         let z_posicion_vertical = sin(anguloEuler) //de la misma forma para el eje z
         //con la inclinación del dispositivo solo nos movemos de lado a lado y alante y atras, la altura no se ve afectada, por ello no la tenemos en cuenta
         
         //print("x \(x_posicion)")
         //print("z \(z_posicion)")
            
        
        //let z_posicion_horizontal = sin((anguloEuler + (Float.pi/2)).truncatingRemainder(dividingBy: 2*Float.pi)) //cogemos el resto por si la suma excede 2Pi
        //sólo quiero saber los radianes en los que está girado, no me interesan cuantas vueltas, por lo que me quedo con el resto de dividirlo entre una vuelta completa (2Pi)
        //quitábamos las vueltas de más al principio para entender mejor los datos, pero el resultado será el mismo, ya que el ángulo de incinación no cambia
        
        //para horizontal, tendremos que girar 45º nuestros angulos dados, por lo que sumamos Pi/2 (en radianes)
        
        let x_posicion_horizontal = cos((anguloEuler + (Float.pi/2)))
        
        let z_posicion_horizontal = sin((anguloEuler + (Float.pi/2)))
        
        if pulsandoPantalla {
            //se está pulsando la pantalla, así que hay que mover el dron con la inclinación del dispositivo
            
            print("Inclinacion horizontal mod: \(Float(inclinacionActualHorizontal))")
            print("Inclinacion vertical mod: \(Float(inclinacionActualVertical))")
            
            //para realizar la animación del dron con respecto al movimiento descrito
            if (inclinacionActualHorizontal<0){ //mover a la derecha
                
                if (movidoHaciaDerecha==false && movidoHaciaIzquierda==true) { //venimos del sentido contrario, por lo que animacion x2, para colocar de derecho y a la vez inclinar hacia nuestro sentido
                    DronNode.runAction(SCNAction.rotateBy(x: 0, y: 0, z: -0.6, duration: 0.5))
                } else if (movidoHaciaDerecha==false){
                    DronNode.runAction(SCNAction.rotateBy(x: 0, y: 0, z: -0.3, duration: 0.5))
                }
                
                movidoHaciaIzquierda = false
                
                movidoHaciaDerecha = true
                
            } else if (inclinacionActualHorizontal>0) { //mover a la izquierda
                
                if (movidoHaciaIzquierda==false && movidoHaciaDerecha==true) {
                    DronNode.runAction(SCNAction.rotateBy(x: 0, y: 0, z: 0.6, duration: 0.5))
                } else if (movidoHaciaIzquierda==false){
                    DronNode.runAction(SCNAction.rotateBy(x: 0, y: 0, z: 0.3, duration: 0.5))
                }
                
                movidoHaciaDerecha = false
                
                movidoHaciaIzquierda = true
                
            } else if (inclinacionActualHorizontal==0){ //va a actuar como si nulo, como si no se pulsase, por lo que aplicamos exactamente la misma animación que cuando dejamos de pulsar
                
                if (movidoHaciaDerecha || movidoHaciaIzquierda){
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.4
                    DronNode.position = SCNVector3(DronNode.position.x + (x_posicion_horizontal * 4 * Float(inclinacionActualHorizontal)), DronNode.position.y, DronNode.position.z - (z_posicion_horizontal * 4 * Float(inclinacionActualHorizontal)))
                    
                    SCNTransaction.commit()
                }
                
                if (movidoHaciaDerecha){ //si anteriormente se ha movido hacia alante, colocamos derecho
                    DronNode.runAction(SCNAction.rotateBy(x: 0, y: 0, z: 0.3, duration: 0.5)) //cuando deja de acelerar hace efecto de detenerse
                    
                    movidoHaciaDerecha = false //para que sólo entre una vez cuando se ha dejado de pulsar
                }
                
                if (movidoHaciaIzquierda){ //si anteriormente se ha movido hacia alante, colocamos derecho
                    
                    DronNode.runAction(SCNAction.rotateBy(x: 0, y: 0, z: -0.3, duration: 0.5)) //cuando deja de acelerar hace efecto de detenerse
                    
                    movidoHaciaIzquierda = false
                }
                
            }
            
            //llevamos acabo la animacion con respecto la inclinacion horizontal, que se ejecutará a la vez que con la inclinación vertical ya que corremos estas animaciones a la vez
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.1
            DronNode.position = SCNVector3(DronNode.position.x + (x_posicion_horizontal * Float(inclinacionActualHorizontal)), DronNode.position.y, DronNode.position.z - (z_posicion_horizontal * Float(inclinacionActualHorizontal))) //convertimos CGFloat a Float
             
            SCNTransaction.commit()
            
            if (inclinacionActualVertical<0) { //mover hacia atrás
                
                if (movidoHaciaAtras==false && movidoHaciaAlante==true) { //si es la primera vez que vamos hacia atras y antes ibamos hacia alante, tenemos que rotar el doble para el efecto de cambiar de sentido
                    DronNode.runAction(SCNAction.rotateBy(x: -0.6, y: 0, z: 0, duration: 0.5))
                } else if (movidoHaciaAtras==false){ //si estamos acelerando despues de haber estado parados nos inclinamos (o sea solo la primera vez)
                    DronNode.runAction(SCNAction.rotateBy(x: -0.3, y: 0, z: 0, duration: 0.5))
                }
                
                movidoHaciaAlante = false //para que cuando dejemos de pulsar no haga el efecto de pararse con el que ya no se ha movido por ultima vez
                
                movidoHaciaAtras = true
                
            } else { //mover hacia alante
                
                if (movidoHaciaAlante==false && movidoHaciaAtras==true) {
                    DronNode.runAction(SCNAction.rotateBy(x: 0.6, y: 0, z: 0, duration: 0.5))
                } else if (movidoHaciaAlante==false){ //si estamos acelerando despues de haber estado parados nos inclinamos (o sea solo la primera vez)
                    //inclinarse hacia adelante cuando se acelera hacia alante
                    DronNode.runAction(SCNAction.rotateBy(x: 0.3, y: 0, z: 0, duration: 0.5))
                }
                
                movidoHaciaAtras = false //para que cuando dejemos de pulsar no haga el efecto de pararse con el que ya no se ha movido por ultima vez
                
                movidoHaciaAlante = true
            }
            
            //no contemplamos con otra condición cuando pueda valer 0 la inclinación vertical ya que pasa directamente de un sentido a otro según la aceleración, en la inclinación horizontal no pasaba así ya que descartábamos inclinaciones mínimas (<minimoConsiderar = 0.13) estableciéndolas en 0
            
            
            /*
            print("Euler x: \((Float(DronNode.eulerAngles.x)).truncatingRemainder(dividingBy: 2*Float.pi))")
            print("Euler y: \((Float(DronNode.eulerAngles.y)).truncatingRemainder(dividingBy: 2*Float.pi))")
            print("Euler z: \((Float(DronNode.eulerAngles.z)).truncatingRemainder(dividingBy: 2*Float.pi))")
             */
            
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.1
            DronNode.position = SCNVector3(DronNode.position.x + (x_posicion_vertical * Float(inclinacionActualVertical)), DronNode.position.y, DronNode.position.z - (z_posicion_vertical * Float(inclinacionActualVertical))) //convertimos CGFloat a Float
             
            SCNTransaction.commit()
            
            
            
        } else {
            //no está pulsando la pantalla
            
            if (movidoHaciaAlante || movidoHaciaAtras){ //realiazamos un efecto de frenado
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.4 //0.4 = duracion de animaciones desplazamiento (0.1) x 4
                DronNode.position = SCNVector3(DronNode.position.x + (x_posicion_vertical * 4 * Float(inclinacionActualVertical)), DronNode.position.y, DronNode.position.z - (z_posicion_vertical * 4 * Float(inclinacionActualVertical))) //x4 al igual que la duracion de la animacion, para que corra a la misma velocidad que en el desplazamiento normal
                
                SCNTransaction.commit()
            }
            
            if (movidoHaciaAlante){ //si anteriormente se ha movido hacia alante, colocamos derecho
                DronNode.runAction(SCNAction.rotateBy(x: -0.3, y: 0, z: 0, duration: 0.4)) //cuando deja de acelerar hace efecto de detenerse
                
                movidoHaciaAlante = false //para que sólo entre una vez cuando se ha dejado de pulsar
            }
            
            if (movidoHaciaAtras){
                
                DronNode.runAction(SCNAction.rotateBy(x: 0.3, y: 0, z: 0, duration: 0.4))
                
                movidoHaciaAtras = false
            }
            
            
            if (movidoHaciaDerecha || movidoHaciaIzquierda){
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.4
                DronNode.position = SCNVector3(DronNode.position.x + (x_posicion_horizontal * 4 * Float(inclinacionActualHorizontal)), DronNode.position.y, DronNode.position.z - (z_posicion_horizontal * 4 * Float(inclinacionActualHorizontal)))
                
                SCNTransaction.commit()
            }
            
            if (movidoHaciaDerecha){
                DronNode.runAction(SCNAction.rotateBy(x: 0, y: 0, z: 0.3, duration: 0.4))
                
                movidoHaciaDerecha = false
            }
            
            if (movidoHaciaIzquierda){
                
                DronNode.runAction(SCNAction.rotateBy(x: 0, y: 0, z: -0.3, duration: 0.4))
                
                movidoHaciaIzquierda = false
            }
        }
    }
    
    func mostrarAviso() {
        
        let alerta = UIAlertController(title: "Aviso", message: "Sitúese en un lugar con buenas condiciones de luz y texturas bien definidas para un tracking correcto. Deberá colocarse frente a la siguiente pista de despegue.", preferredStyle: .alert)

        let accionImagen = UIAlertAction(title: "", style: .default, handler: nil)
        let accionOK = UIAlertAction(title: "Vale, gracias", style: .default, handler: nil)
        
        accionImagen.setValue(UIImage(named: "Pista245x245.png")?.withRenderingMode(UIImage.RenderingMode.alwaysOriginal), forKey: "image")
        alerta.addAction(accionImagen)
        alerta.addAction(accionOK)

        self.present(alerta, animated: true, completion: nil)
    }
        
}
