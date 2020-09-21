
module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Localhost
      port: 7545,            // Standard Ganache UI port
      network_id: "*",
      gas:6721975
    }
  },
  compilers: {
    solc: {
      version: "^0.5.0"
    }
  }
};